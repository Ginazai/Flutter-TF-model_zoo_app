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
  double _calibrationFactor = 2.3;

  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/depth/Depth-Anything-V2_float.tflite');
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
      await Logger.log('Depth model not initialized after initialize() call. Returning default DepthResult.');
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

      int height = _inputShape.length > 1 ? _inputShape[1] : 256;
      int width = _inputShape.length > 2 ? _inputShape[2] : 256;

      if (height > 518 || width > 518) {
        await Logger.log('Model input too large (height=$height width=$width). Capping to 256x256.');
        height = 256;
        width = 256;
      }

      final resized = img.copyResize(image, width: width, height: height);

      // Create properly shaped input buffer: [1, height, width, 3]
      final inputBuffer = _preprocessToShapedBuffer(resized, height, width);

      int outputSize = _outputShape.reduce((a, b) => a * b);

      // Create properly shaped output buffer
      final outputBuffer = _createOutputBuffer();

      await Logger.log('Running inference. input (${height}x${width}), expected output size: $outputSize');

      try {
        _interpreter?.run(inputBuffer, outputBuffer);
      } catch (e) {
        await Logger.log('Inference error: $e');
        return DepthResult(hasCollision: false, minDistance: 999);
      }

      int outH = _outputShape.length > 1 ? _outputShape[1] : height;
      int outW = _outputShape.length > 2 ? _outputShape[2] : width;

      // Extract output from shaped buffer
      List<List<double>> depth2D = await _extractDepthMapFromShaped(outputBuffer, outH, outW);
      if (depth2D.isEmpty) {
        await Logger.log('Depth map extraction returned empty result. Returning default DepthResult.');
        return DepthResult(hasCollision: false, minDistance: 999);
      }

      var stats = _analyzeDepth(depth2D);
      double globalMin = stats['globalMin']!;
      double globalMax = stats['globalMax']!;
      double minValue = stats['minValue']!;

      double normalizedDepth = 0.0;
      if (globalMax != globalMin) {
        normalizedDepth = (minValue - globalMin) / (globalMax - globalMin);
      }

      double distance = 1.0 - normalizedDepth;
      double minDistanceCm = distance * 100.0 * _calibrationFactor;

      await Logger.log('Depth estimation done. distance=$distance minDistance=$minDistanceCm globalMin=$globalMin globalMax=$globalMax');

      return DepthResult(
        hasCollision: distance < 0.6,
        minDistance: minDistanceCm,
        depthMap: depth2D,
      );
    } finally {
      _inferenceRunning = false;
    }
  }

  // Create shaped buffer [1, height, width, 3]
  List<List<List<List<double>>>> _preprocessToShapedBuffer(img.Image image, int height, int width) {
    List<List<List<List<double>>>> shaped = [
      List.generate(height, (y) =>
          List.generate(width, (x) {
            var pixel = image.getPixel(x, y);
            num r = pixel.r;
            num g = pixel.g;
            num b = pixel.b;
            return [
              ((r / 255.0) - MEAN[0]) / STD[0],
              ((g / 255.0) - MEAN[1]) / STD[1],
              ((b / 255.0) - MEAN[2]) / STD[2],
            ];
          })
      )
    ];
    return shaped;
  }

  // Create output buffer matching output shape
  dynamic _createOutputBuffer() {
    if (_outputShape.length == 4) {
      // [batch, height, width, channels]
      return List.generate(
          _outputShape[0],
              (_) => List.generate(
              _outputShape[1],
                  (_) => List.generate(
                  _outputShape[2],
                      (_) => List.filled(_outputShape[3], 0.0)
              )
          )
      );
    } else if (_outputShape.length == 3) {
      // [batch, height, width]
      return List.generate(
          _outputShape[0],
              (_) => List.generate(
              _outputShape[1],
                  (_) => List.filled(_outputShape[2], 0.0)
          )
      );
    } else {
      // Fallback to flat array
      return Float32List(_outputShape.reduce((a, b) => a * b));
    }
  }

  Future<List<List<double>>> _extractDepthMapFromShaped(dynamic output, int height, int width) async {
    List<List<double>> depth2D = [];
    try {
      if (output is List) {
        // Handle shaped output [batch, height, width] or [batch, height, width, channels]
        var batch0 = output[0];
        if (batch0 is List) {
          for (int y = 0; y < height && y < batch0.length; y++) {
            List<double> row = [];
            var rowData = batch0[y];
            if (rowData is List) {
              for (int x = 0; x < width && x < rowData.length; x++) {
                var val = rowData[x];
                // If channels exist, take first channel
                if (val is List && val.isNotEmpty) {
                  row.add((val[0] as num).toDouble());
                } else {
                  row.add((val as num).toDouble());
                }
              }
            }
            depth2D.add(row);
          }
        }
      } else if (output is Float32List) {
        // Fallback for flat output
        for (int y = 0; y < height; y++) {
          List<double> row = [];
          for (int x = 0; x < width; x++) {
            int index = y * width + x;
            if (index < output.length) {
              row.add(output[index]);
            }
          }
          depth2D.add(row);
        }
      }
    } catch (e) {
      await Logger.log('Error extracting depth map: $e');
      return [];
    }
    return depth2D;
  }

  Map<String, double> _analyzeDepth(List<List<double>> depthMap) {
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    int h = depthMap.length;
    int w = depthMap.isNotEmpty ? depthMap[0].length : 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double val = depthMap[y][x];
        if (val < globalMin) globalMin = val;
        if (val > globalMax) globalMax = val;
      }
    }

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