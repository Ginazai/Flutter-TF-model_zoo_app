import 'dart:typed_data';
import 'dart:core';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/depth_result.dart';
import '../utils/logger.dart';

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
      await Logger.log('DEPTH: initialize - starting');
      _interpreter = await Interpreter.fromAsset(
        'assets/models/depth/Depth-Anything-V2_float.tflite',
      );
      //
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      _isInitialized = true;
      await Logger.log('DEPTH: initialize - finished input=$_inputShape output=$_outputShape');
      print('Depth model initialized. inputShape=$_inputShape outputShape=$_outputShape');
    } catch (e) {
      await Logger.log('DEPTH: initialize - error: $e');
      print('Error initializing depth model: $e');
    }
  }

  Future<DepthResult> estimateDepth(Uint8List imageBytes) async {
    await Logger.log('DEPTH: estimateDepth - starting');
    if (!_isInitialized) await initialize();
    if (!_isInitialized) {
      await Logger.log('DEPTH: estimateDepth - not initialized');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null || imageBytes.length > 10000000) {
      await Logger.log('DEPTH: estimateDepth - invalid image or too large (${imageBytes.length})');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    int height = _inputShape.length > 1 ? _inputShape[1] : 256;
    int width = _inputShape.length > 2 ? _inputShape[2] : 256;

    if (height > 518 || width > 518) {
      height = 256;
      width = 256;
      await Logger.log('DEPTH: estimateDepth - input shape too large, downscaling to 256x256');
    } else {
      await Logger.log('DEPTH: estimateDepth - using model input $height x $width');
    }

    final resized = img.copyResize(image, width: width, height: height);
    await Logger.log('DEPTH: preprocessing - resized image to ${resized.width}x${resized.height}');

    // Construir input con forma [1, height, width, 3]
    final input = _preprocessTo4DList(resized, height, width);

    // determinar dimensiones de salida robustamente
    int outH = 0;
    int outW = 0;
    int outC = 1; // asumir canal 1 por defecto
    if (_outputShape.length >= 4) {
      // forma típica: [1, H, W, C]
      outH = _outputShape[_outputShape.length - 3];
      outW = _outputShape[_outputShape.length - 2];
      outC = _outputShape[_outputShape.length - 1];
    } else if (_outputShape.length == 3) {
      // posible forma: [1, H, W] o [H, W, C]
      // intentar inferir H,W como posiciones 1,2 si primer elemento es batch=1
      if (_outputShape[0] == 1) {
        outH = _outputShape[1];
        outW = _outputShape[2];
      } else {
        outH = _outputShape[0];
        outW = _outputShape[1];
        outC = _outputShape[2];
      }
    } else if (_outputShape.length == 2) {
      outH = _outputShape[0];
      outW = _outputShape[1];
    } else {
      outH = 256;
      outW = 256;
      outC = 1;
    }

    // Crear buffer de salida con forma acorde al modelo: si hay dim de canal crear [1,H,W,C], si no [1,H,W]
    final bool hasChannelDim = (_outputShape.length >= 4) || (outC > 1);
    dynamic outputTensor;
    if (hasChannelDim) {
      outputTensor = List.generate(1, (_) => List.generate(outH, (_) => List.generate(outW, (_) => List.filled(outC, 0.0))));
    } else {
      outputTensor = List.generate(1, (_) => List.generate(outH, (_) => List.filled(outW, 0.0)));
    }

    try {
      await Logger.log('DEPTH: running inference (input shape [1,$height,$width,3], output shape ${hasChannelDim ? '[1,$outH,$outW,$outC]' : '[1,$outH,$outW]'})');
      _interpreter?.run(input, outputTensor);
      await Logger.log('DEPTH: finished inference');
    } catch (e) {
      await Logger.log('DEPTH: inference error: $e');
      print('Inference error: $e');
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // Extraer mapa de profundidad desde outputTensor[0] manejando [1,H,W] y [1,H,W,1]
    List<List<double>> depth2D = _extractDepthMapFromNested(outputTensor, outH, outW, outC, hasChannelDim);

    if (depth2D.isEmpty) {
      await Logger.log('DEPTH: extractDepthMap - empty output');
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
    // Nota: umbral heurístico
    bool collision = distance < 0.6;
    double minDistPct = distance * 100;

    await Logger.log('DEPTH: analysis - hasCollision=$collision normalizedDepth=${normalizedDepth.toStringAsFixed(4)} minDistancePct=${minDistPct.toStringAsFixed(2)}% (raw min=$minValue globalMin=$globalMin globalMax=$globalMax)');

    return DepthResult(
      hasCollision: collision,
      minDistance: minDistPct,
      depthMap: depth2D,
    );
  }

  // Devuelve List\[1][H][W][3] para pasar al intérprete
  List<List<List<List<double>>>> _preprocessTo4DList(img.Image image, int height, int width) {
    return List.generate(1, (_) => List.generate(height, (y) {
      return List.generate(width, (x) {
        final pixel = image.getPixel(x, y);
        final double r = ((pixel.r / 255.0) - MEAN[0]) / STD[0];
        final double g = ((pixel.g / 255.0) - MEAN[1]) / STD[1];
        final double b = ((pixel.b / 255.0) - MEAN[2]) / STD[2];
        return [r, g, b];
      });
    }));
  }

  List<List<double>> _extractDepthMapFromNested(dynamic output, int height, int width, int channels, bool hasChannelDim) {
    List<List<double>> depth2D = [];

    try {
      if (output == null) {
        Logger.log('DEPTH: _extractDepthMapFromNested - null output object');
        return [];
      }

      // output expected either: List[1][H][W] or List[1][H][W][C]
      final first = output[0];
      if (first == null) return [];

      for (int y = 0; y < height; y++) {
        List<double> row = [];
        final rowList = first[y] as List;
        for (int x = 0; x < width; x++) {
          final cell = rowList[x];
          if (cell is num) {
            row.add(cell.toDouble());
          } else if (cell is List && cell.isNotEmpty && cell[0] is num) {
            // toma el primer canal si hay canales (habitualmente C==1)
            row.add((cell[0] as num).toDouble());
          } else {
            row.add(0.0);
          }
        }
        depth2D.add(row);
      }
    } catch (e) {
      Logger.log('DEPTH: _extractDepthMapFromNested - error: $e');
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

    return {
      'minValue': minValue,
      'globalMin': globalMin,
      'globalMax': globalMax,
    };
  }

  void dispose() {
    _interpreter?.close();
    Logger.log('DEPTH: dispose');
  }
}