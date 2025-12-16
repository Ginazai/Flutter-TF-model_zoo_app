import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/depth_result.dart';

class DepthEstimationService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<int> _inputShape = [];
  List<int> _outputShape = [];

  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/depth/Depth-Anything-V2_float.tflite',
      );

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      _isInitialized = true;
      print('Depth model initialized. inputShape=$_inputShape outputShape=$_outputShape');
    } catch (e) {
      print('Error initializing depth model: $e');
    }
  }

  Future<DepthResult> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null || imageBytes.length > 10000000) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // Get dimensions from model shape
    int height = _inputShape[1];
    int width = _inputShape[2];

    // Limit max size to prevent crashes
    if (height > 518 || width > 518) {
      height = 256;
      width = 256;
    }

    // Resize image to model input size
    final resized = img.copyResize(image, width: width, height: height);

    // Preprocess to Float32List
    final inputBuffer = _preprocessToBuffer(resized, height, width);

    // Calculate output size
    int outputSize = _outputShape.reduce((a, b) => a * b);
    final outputBuffer = Float32List(outputSize);

    // Run inference with typed buffers
    try {
      _interpreter?.run(
          inputBuffer.buffer.asUint8List(),
          outputBuffer.buffer.asUint8List()
      );
    } catch (e) {
      print('Inference error: $e');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // Extract depth map from output buffer
    int outH = _outputShape[1];
    int outW = _outputShape[2];

    List<List<double>> depth2D = _extractDepthMap(outputBuffer, outH, outW);

    if (depth2D.isEmpty) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // Analyze depth
    var stats = _analyzeDepth(depth2D);
    double globalMin = stats['globalMin']!;
    double globalMax = stats['globalMax']!;
    double minValue = stats['minValue']!;

    double normalizedDepth = 0.0;
    if (globalMax != globalMin) {
      normalizedDepth = (minValue - globalMin) / (globalMax - globalMin);
    }

    double distance = 1.0 - normalizedDepth;

    return DepthResult(
      hasCollision: distance < 0.6,
      minDistance: distance * 100,
      depthMap: depth2D,
    );
  }

  Float32List _preprocessToBuffer(img.Image image, int height, int width) {
    final buffer = Float32List(height * width * 3);
    int index = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        buffer[index++] = ((pixel.r / 255.0) - MEAN[0]) / STD[0];
        buffer[index++] = ((pixel.g / 255.0) - MEAN[1]) / STD[1];
        buffer[index++] = ((pixel.b / 255.0) - MEAN[2]) / STD[2];
      }
    }

    return buffer;
  }

  List<List<double>> _extractDepthMap(Float32List output, int height, int width) {
    List<List<double>> depth2D = [];

    try {
      int expectedSize = height * width;
      if (output.length < expectedSize) {
        print('Output buffer too small: ${output.length} < $expectedSize');
        return [];
      }

      for (int y = 0; y < height; y++) {
        List<double> row = [];
        for (int x = 0; x < width; x++) {
          int index = y * width + x;
          row.add(output[index]);
        }
        depth2D.add(row);
      }
    } catch (e) {
      print('Error extracting depth map: $e');
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

    // Analyze central region
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

    return {
      'minValue': minValue,
      'globalMin': globalMin,
      'globalMax': globalMax,
    };
  }

  void dispose() {
    _interpreter?.close();
  }
}