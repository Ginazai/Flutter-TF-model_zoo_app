import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/depth_result.dart';
import '../utils/logger.dart';

class DepthEstimationService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<int> _inputShape = [];
  List<int> _outputShape = [];
  bool _inferenceRunning = false;
  double _calibrationFactor = 1.0;

  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/depth/depth_anything_metric_nhwc.tflite');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      _isInitialized = true;
      await Logger.log('Depth model initialized. inputShape=$_inputShape outputShape=$_outputShape');
    } catch (e) {
      await Logger.log('Error initializing depth model: $e');
    }
  }

  void calibrate(double realCm, double measuredPredictedCm) {
    if (measuredPredictedCm > 0) {
      _calibrationFactor = realCm / measuredPredictedCm;
      Logger.log('Depth calibration set. factor=$_calibrationFactor (real=$realCm measured=$measuredPredictedCm)');
    }
  }

  Future<DepthResult> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) {
      await Logger.log('Depth model not initialized. Returning default DepthResult.');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    if (_inferenceRunning) {
      await Logger.log('Skipping estimateDepth because another inference is running.');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    _inferenceRunning = true;
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null || imageBytes.length > 10000000) {
        await Logger.log('Invalid image or image too large. length=${imageBytes.length}');
        return DepthResult(hasCollision: false, minDistance: 999);
      }

      // Determine input dimensions and format
      int height = 384;
      int width = 384;
      bool inputIsNCHW = false;

      if (_inputShape.length == 4) {
        if (_inputShape[1] == 3) {
          inputIsNCHW = true;
          height = _inputShape[2];
          width = _inputShape[3];
        } else if (_inputShape[3] == 3) {
          inputIsNCHW = false;
          height = _inputShape[1];
          width = _inputShape[2];
        }
      }

      await Logger.log('Resizing image to ${width}x${height} (${inputIsNCHW ? "NCHW" : "NHWC"})');
      final resized = img.copyResize(image, width: width, height: height);

      // Create input as nested list structure (required by ai_edge_torch models)
      final inputObject = _buildInputObjectNested(resized, height, width, inputIsNCHW);

      // Create output buffer as nested list
      final outputObject = _createNestedOutputList(_outputShape);

      await Logger.log('Running inference. outputShape=$_outputShape');

      try {
        _interpreter!.run(inputObject, outputObject);
      } catch (e) {
        await Logger.log('Inference error: $e');
        return DepthResult(hasCollision: false, minDistance: 999);
      }

      // Extract depth map
      List<List<double>> depth2D = _extractDepthMapFromOutputObject(outputObject, _outputShape);
      if (depth2D.isEmpty) {
        await Logger.log('Depth map extraction returned empty result.');
        return DepthResult(hasCollision: false, minDistance: 999);
      }

      // Analyze depth (Depth Anything V2 Metric outputs actual depth values in meters)
      var stats = _analyzeDepth(depth2D);
      double globalMin = stats['globalMin'] ?? 0.0;
      double globalMax = stats['globalMax'] ?? 0.0;
      double minValue = stats['minValue'] ?? 0.0;

      // Depth Anything V2 Metric outputs depth in meters
      // Lower values = closer objects (unlike inverse depth)
      double minDistanceMeters = minValue * _calibrationFactor;
      double minDistanceCm = minDistanceMeters * 100.0;

      await Logger.log('Depth estimation done. minDistance=${minDistanceCm.toStringAsFixed(1)} cm (${minDistanceMeters.toStringAsFixed(3)}m), globalMin=$globalMin globalMax=$globalMax');

      // Collision detection: less than 60cm
      bool hasCollision = minDistanceCm < 60.0;

      return DepthResult(
        hasCollision: hasCollision,
        minDistance: minDistanceCm,
        depthMap: depth2D,
      );
    } finally {
      _inferenceRunning = false;
    }
  }

  // Build input as nested list structure (required for ai_edge_torch models)
  dynamic _buildInputObjectNested(img.Image image, int height, int width, bool channelsFirst) {
    if (channelsFirst) {
      // NCHW format: [1, 3, H, W]
      List<List<List<List<double>>>> input = [[]];

      for (int c = 0; c < 3; c++) {
        List<List<double>> channel = [];
        for (int y = 0; y < height; y++) {
          List<double> row = [];
          for (int x = 0; x < width; x++) {
            var pixel = image.getPixel(x, y);
            double val;
            if (c == 0) {
              val = (pixel.r / 255.0 - MEAN[0]) / STD[0];
            } else if (c == 1) {
              val = (pixel.g / 255.0 - MEAN[1]) / STD[1];
            } else {
              val = (pixel.b / 255.0 - MEAN[2]) / STD[2];
            }
            row.add(val);
          }
          channel.add(row);
        }
        input[0].add(channel);
      }
      return input;
    } else {
      // NHWC format: [1, H, W, 3]
      List<List<List<List<double>>>> input = [[]];

      for (int y = 0; y < height; y++) {
        List<List<double>> row = [];
        for (int x = 0; x < width; x++) {
          var pixel = image.getPixel(x, y);
          List<double> pixelValues = [
            (pixel.r / 255.0 - MEAN[0]) / STD[0],
            (pixel.g / 255.0 - MEAN[1]) / STD[1],
            (pixel.b / 255.0 - MEAN[2]) / STD[2],
          ];
          row.add(pixelValues);
        }
        input[0].add(row);
      }
      return input;
    }
  }

  dynamic _createNestedOutputList(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    dynamic build(int dimIndex) {
      int len = shape[dimIndex];
      if (dimIndex == shape.length - 1) {
        return List<double>.filled(len, 0.0);
      } else {
        return List.generate(len, (_) => build(dimIndex + 1));
      }
    }
    return build(0);
  }

  List<List<double>> _extractDepthMapFromOutputObject(dynamic outputObj, List<int> shape) {
    List<List<double>> depth2D = [];
    try {
      if (shape.isEmpty) return depth2D;

      if (shape.length == 3) {
        // [1, H, W]
        int outH = shape[1];
        int outW = shape[2];
        for (int y = 0; y < outH; y++) {
          List<double> row = [];
          for (int x = 0; x < outW; x++) {
            double val = (outputObj[0][y][x] as num).toDouble();
            row.add(val);
          }
          depth2D.add(row);
        }
      } else if (shape.length == 4) {
        int a = shape[1];
        int b = shape[2];
        int c = shape[3];

        if (a > 1 && b > 1) {
          // [1, H, W, C]
          int outH = a;
          int outW = b;
          for (int y = 0; y < outH; y++) {
            List<double> row = [];
            for (int x = 0; x < outW; x++) {
              double val = (outputObj[0][y][x][0] as num).toDouble();
              row.add(val);
            }
            depth2D.add(row);
          }
        } else if (a == 1 && b > 1 && c > 1) {
          // [1, 1, H, W]
          int outH = b;
          int outW = c;
          for (int y = 0; y < outH; y++) {
            List<double> row = [];
            for (int x = 0; x < outW; x++) {
              double val = (outputObj[0][0][y][x] as num).toDouble();
              row.add(val);
            }
            depth2D.add(row);
          }
        }
      }

      return depth2D;
    } catch (e) {
      Logger.log('Error extracting depth map: $e');
      return [];
    }
  }

  Map<String, double> _analyzeDepth(List<List<double>> depthMap) {
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    int h = depthMap.length;
    int w = depthMap.isNotEmpty ? depthMap[0].length : 0;

    // Find global min/max
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double val = depthMap[y][x];
        if (val < globalMin) globalMin = val;
        if (val > globalMax) globalMax = val;
      }
    }

    // Analyze center region (30%-70% of image)
    int y0 = (h * 0.3).floor();
    int y1 = (h * 0.7).floor();
    int x0 = (w * 0.3).floor();
    int x1 = (w * 0.7).floor();

    if (y1 <= y0 || x1 <= x0) {
      y0 = 0;
      y1 = h;
      x0 = 0;
      x1 = w;
    }

    // Find MINIMUM in center region (Depth Anything Metric: lower = closer)
    double minValue = double.infinity;
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        double val = depthMap[y][x];
        if (val < minValue) minValue = val;
      }
    }

    if (globalMin == double.infinity) globalMin = 0.0;
    if (globalMax == double.negativeInfinity) globalMax = 0.0;
    if (minValue == double.infinity) minValue = 0.0;

    Logger.log('Depth analysis: minValue=$minValue globalMin=$globalMin globalMax=$globalMax');

    return {
      'minValue': minValue,
      'globalMin': globalMin,
      'globalMax': globalMax,
    };
  }

  void dispose() {
    _interpreter?.close();
    Logger.log('DepthEstimationService disposed.');
  }
}