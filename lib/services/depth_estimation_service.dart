import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/depth_result.dart';

class DepthEstimationService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // ImageNet normalization values
  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  // Inicializar modelo (llamar UNA VEZ al inicio)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/depth/midas.tflite',
      );
      _isInitialized = true;
      print('MiDaS inicializado');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Procesar imagen y retornar resultado
  Future<DepthResult> estimateDepth(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();

    // 1. Decodificar imagen
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      return DepthResult(hasCollision: false, minDistance: 999);
    }

    // 2. Preprocesar (ImageNet normalization)
    final resized = img.copyResize(image, width: 256, height: 256);
    var input = _preprocessImage(resized);

    // 3. Inferencia - output shape [1, 256, 256, 1]
    var output = List.generate(1, (_) =>
        List.generate(256, (_) =>
            List.generate(256, (_) => List.filled(1, 0.0))
        )
    );

    _interpreter?.run(input, output);

    // 4. Analizar resultado
    var depthMap = output[0];
    var stats = _analyzeDepth(depthMap);

    // Normalizar depth a rango [0, 1]
    double normalizedDepth = (stats['minValue']! - stats['globalMin']!) /
        (stats['globalMax']! - stats['globalMin']!);

    // Convertir a distancia estimada en metros (0 = cerca, 1 = lejos)
    // Invertir porque depth menor = más cerca
    double distance = 1.0 - normalizedDepth; // Escala 0-5 metros

    // double _calibrateToMeters(double normalizedDepth) {
    //   // Replace with your actual measurements
    //   if (normalizedDepth > 0.5) return 0.125;  // Very close
    //   if (normalizedDepth > 0.4) return 0.25;
    //   if (normalizedDepth > 0.3) return 0.5;
    //   if (normalizedDepth > 0.2) return 1.0;
    //   return 5.0; // Far
    // }
    // double distance = _calibrateToMeters(normalizedDepth);


    return DepthResult(
      hasCollision: distance < 0.6, // Umbral de colisión
      minDistance: distance * 100,
      depthMap: depthMap.map((row) => row.map((pixel) => pixel[0]).toList()).toList(),
    );
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // ImageNet normalization: (pixel/255 - mean) / std
    return List.generate(1, (_) =>
        List.generate(256, (y) =>
            List.generate(256, (x) {
              final pixel = image.getPixel(x, y);
              return [
                ((pixel.r / 255.0) - MEAN[0]) / STD[0],
                ((pixel.g / 255.0) - MEAN[1]) / STD[1],
                ((pixel.b / 255.0) - MEAN[2]) / STD[2],
              ];
            })
        )
    );
  }

  Map<String, double> _analyzeDepth(List<List<List<double>>> depthMap) {
    // Encontrar min/max global
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        double val = depthMap[y][x][0];
        if (val < globalMin) globalMin = val;
        if (val > globalMax) globalMax = val;
      }
    }

    // Analizar zona central (donde está el objeto más cercano)
    double minValue = double.infinity;
    for (int y = 76; y < 180; y++) {
      for (int x = 76; x < 180; x++) {
        double val = depthMap[y][x][0];
        if (val < minValue) {
          minValue = val;
        }
      }
    }

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