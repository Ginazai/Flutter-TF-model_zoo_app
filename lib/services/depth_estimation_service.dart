// dart
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/depth_result.dart';

class DepthEstimationService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<int> _inputShape = [];
  List<int> _outputShape = [];

  // ImageNet normalization values
  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  // Inicializar modelo (llamar UNA VEZ al inicio)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/depth/Depth-Anything-V2_float.tflite',
      );

      // Read model input/output shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      _isInitialized = true;
      print('Depth model initialized. inputShape=$_inputShape outputShape=$_outputShape');
    } catch (e) {
      print('Error initializing depth model: $e');
    }
  }

  // Procesar imagen y retornar resultado
  Future<DepthResult> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();

    if (!_isInitialized) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // 1. Decodificar imagen
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // Determine input geometry & format (supports NHWC and NCHW)
    int inBatch = _inputShape.length > 0 ? _inputShape[0] : 1;
    int in1 = _inputShape.length > 1 ? _inputShape[1] : 256;
    int in2 = _inputShape.length > 2 ? _inputShape[2] : 256;
    int in3 = _inputShape.length > 3 ? _inputShape[3] : 3;

    bool isNCHW = false;
    int height = 256;
    int width = 256;
    int channels = 3;

    if (_inputShape.length == 4 && in1 == 3 && in2 > 1 && in3 > 1) {
      // [1, C, H, W]
      isNCHW = true;
      channels = in1;
      height = in2;
      width = in3;
    } else if (_inputShape.length >= 4) {
      // assume [1, H, W, C]
      isNCHW = false;
      height = in1;
      width = in2;
      channels = in3;
    } else if (_inputShape.length == 3) {
      // [H, W, C] or [1,H,W]
      height = in1;
      width = in2;
      channels = in3;
    }

    // 2. Preprocesar (ImageNet normalization) - resize to model input
    final resized = img.copyResize(image, width: width, height: height);
    var input = _preprocessImage(resized, height, width, channels, isNCHW);

    // 3. Prepare output container based on output shape
    var output = _createNestedListFromShape(_outputShape, 0.0);

    // Run inference
    try {
      _interpreter?.run(input, output);
    } catch (e) {
      print('Inference error: $e');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // 4. Extract a 2D depth map (H x W) from the model output
    int outH = 256;
    int outW = 256;
    // Try to infer outH/outW from shape (pick dims >1 excluding batch & channel)
    var dims = _outputShape;
    List<int> nonOnes = [];
    for (int i = 1; i < dims.length; i++) {
      if (dims[i] > 1) nonOnes.add(dims[i]);
    }
    if (nonOnes.length >= 2) {
      outH = nonOnes[0];
      outW = nonOnes[1];
    } else if (nonOnes.length == 1) {
      outH = nonOnes[0];
      outW = nonOnes[0];
    }

    List<List<double>>? depth2D = _find2DList(output);
    if (depth2D == null || depth2D.isEmpty) {
      print('Could not extract 2D depth map from output');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // ensure dimensions match expected outH/outW (if not, try to adapt)
    // If size differs, resize depth2D to outH/outW by simple cropping/padding
    if (depth2D.length != outH || depth2D[0].length != outW) {
      // Simple adapt: crop or pad with zeros
      List<List<double>> adapted = List.generate(outH, (y) =>
          List.generate(outW, (x) {
            final d2 = depth2D!;
            final d2w = d2.isNotEmpty ? d2[0].length : 0;
            List<List<double>> adapted = List.generate(outH, (y) =>
                List.generate(outW, (x) {
                  if (y < d2.length && x < d2w) return d2[y][x];
                  return 0.0;
                })
            );
            depth2D = adapted;            return 0.0;
          })
      );
      depth2D = adapted;
    }

    // Analyze depth
    var stats = _analyzeDepth(depth2D!);
    double globalMin = stats['globalMin']!;
    double globalMax = stats['globalMax']!;
    double minValue = stats['minValue']!;

    double normalizedDepth = 0.0;
    if (globalMax != globalMin) {
      normalizedDepth = (minValue - globalMin) / (globalMax - globalMin);
    }

    // Invert because depth lower = closer
    double distance = 1.0 - normalizedDepth;

    return DepthResult(
      hasCollision: distance < 0.6,
      minDistance: distance * 100,
      depthMap: depth2D,
    );
  }

  dynamic _preprocessImage(img.Image image, int height, int width, int channels, bool isNCHW) {
    // ImageNet normalization: (pixel/255 - mean) / std
    if (isNCHW) {
      // [1, C, H, W]
      return List.generate(1, (_) =>
          List.generate(channels, (c) =>
              List.generate(height, (y) =>
                  List.generate(width, (x) {
                    final pixel = image.getPixel(x, y);
                    double r = (pixel.r / 255.0 - MEAN[0]) / STD[0];
                    double g = (pixel.g / 255.0 - MEAN[1]) / STD[1];
                    double b = (pixel.b / 255.0 - MEAN[2]) / STD[2];
                    if (c == 0) return r;
                    if (c == 1) return g;
                    return b;
                  })
              )
          )
      );
    } else {
      // [1, H, W, C]
      return List.generate(1, (_) =>
          List.generate(height, (y) =>
              List.generate(width, (x) {
                final pixel = image.getPixel(x, y);
                return [
                  ((pixel.r / 255.0) - MEAN[0]) / STD[0],
                  ((pixel.g / 255.0) - MEAN[1]) / STD[1],
                  ((pixel.b / 255.0) - MEAN[2]) / STD[2],
                ].sublist(0, channels);
              })
          )
      );
    }
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

    // Analyze a central region (fallback to full if too small)
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

  dynamic _createNestedListFromShape(List<int> shape, double fill) {
    if (shape.isEmpty) return fill;
    int len = shape[0];
    if (shape.length == 1) return List<double>.filled(len, fill);
    return List.generate(len, (_) => _createNestedListFromShape(shape.sublist(1), fill));
  }

  List<List<double>>? _find2DList(dynamic o) {
    // Try to find a 2D numeric list inside nested lists
    if (o is List) {
      // Direct 2D of numbers
      if (o.isNotEmpty && o[0] is List && o[0].isNotEmpty && (o[0][0] is num || o[0][0] is List)) {
        // Case: List<List<num>>
        if (o[0][0] is num) {
          return o.map<List<double>>((row) => (row as List).map<double>((v) => (v as num).toDouble()).toList()).toList();
        }
        // Case: List<List<List<num>>> -> take inner[0]
        if (o[0][0] is List) {
          // If innermost is numeric
          if ((o[0][0] as List).isNotEmpty && (o[0][0][0] is num)) {
            return o.map<List<double>>((row) =>
                (row as List).map<double>((cell) {
                  if (cell is List && cell.isNotEmpty && cell[0] is num) return (cell[0] as num).toDouble();
                  if (cell is num) return (cell as num).toDouble();
                  return 0.0;
                }).toList()
            ).toList();
          }
        }
      }

      // Search deeper
      for (var item in o) {
        var res = _find2DList(item);
        if (res != null) return res;
      }
    }
    return null;
  }

  void dispose() {
    _interpreter?.close();
  }
}
