import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/scene_description.dart';
import '../utils/logger.dart';

class SceneDetectionService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  static const List<String> SCENE_LABELS = [
    'airport_terminal', 'art_gallery', 'auditorium', 'bakery', 'bar',
    'bathroom', 'bedroom', 'bookstore', 'bowling_alley', 'cafeteria',
    'classroom', 'closet', 'clothing_store', 'conference_room', 'corridor',
    'courtyard', 'dining_room', 'elevator', 'garage', 'gym',
    'hallway', 'hospital_room', 'hotel_room', 'kitchen', 'library',
    'living_room', 'lobby', 'office', 'outdoor', 'parking_lot',
    'playground', 'restaurant', 'staircase', 'store', 'street',
    'subway_station', 'supermarket', 'swimming_pool', 'warehouse', 'unknown'
  ];

  static const List<double> MEAN = [0.485, 0.456, 0.406];
  static const List<double> STD = [0.229, 0.224, 0.225];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Logger.log('SCENE: initialize - starting');
      _interpreter = await Interpreter.fromAsset(
        'assets/models/scene/DeepLabV3-Plus-MobileNet_float.tflite',
      );

      _isInitialized = true;
      await Logger.log('SCENE: initialize - finished');
      print('MobileNet inicializado');

      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      await Logger.log('SCENE: initialize - error: $e');
      print('Error inicializando SceneDetectionService: $e');
    }
  }

  Future<SceneDescription> detectScene(Uint8List imageBytes) async {
    await Logger.log('SCENE: detectScene - starting');
    if (!_isInitialized) await initialize();

    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        await Logger.log('SCENE: detectScene - failed to decode image');
        return SceneDescription(
          rawLabel: 'unknown',
          confidence: 0.0,
          naturalDescription: 'No se pudo procesar la imagen',
        );
      }

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputSize = inputShape[1];
      await Logger.log('SCENE: preprocessing - resizing to $inputSize');

      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      var input = _preprocessImage(resized, inputSize);

      await Logger.log('SCENE: running inference');
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      var output = List.generate(
        outputShape[0],
            (_) => List.generate(
          outputShape[1],
              (_) => List.filled(outputShape[2], 0),
        ),
      );

      _interpreter!.run(input, output);
      await Logger.log('SCENE: finished inference');

      var result = _processSegmentationOutput(output);

      String naturalDescription = _createFallbackDescription(
        result['label'] as String,
        result['confidence'] as double,
      );

      await Logger.log('SCENE: result - ${result['label']} with confidence ${(result['confidence'] as double).toStringAsFixed(3)}');
      await Logger.log('SCENE: naturalDescription - $naturalDescription');

      return SceneDescription(
        rawLabel: result['label'] as String,
        confidence: result['confidence'] as double,
        naturalDescription: naturalDescription,
      );
    } catch (e) {
      await Logger.log('SCENE: detectScene - error: $e');
      print('Error en detección de escena: $e');
      return SceneDescription(
        rawLabel: 'unknown',
        confidence: 0.0,
        naturalDescription: 'Error al detectar la escena',
      );
    }
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image, int size) {
    return List.generate(1, (_) =>
        List.generate(size, (y) =>
            List.generate(size, (x) {
              final pixel = image.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            })
        )
    );
  }

  Map<String, dynamic> _processSegmentationOutput(List<dynamic> output) {
    try {
      Map<int, int> classFrequency = {};
      int totalPixels = 0;

      for (int y = 0; y < output[0].length; y++) {
        for (int x = 0; x < output[0][0].length; x++) {
          int classId = output[0][y][x] as int;
          classFrequency[classId] = (classFrequency[classId] ?? 0) + 1;
          totalPixels++;
        }
      }

      classFrequency.remove(0);

      if (classFrequency.isEmpty) {
        return {'label': 'unknown', 'confidence': 0.0};
      }

      var dominantEntry = classFrequency.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      int dominantClass = dominantEntry.key;
      double confidence = dominantEntry.value / totalPixels;

      String label = _getClassLabel(dominantClass);

      print('Dominant class: $label (ID: $dominantClass, ${(confidence * 100).toStringAsFixed(1)}%)');

      return {
        'label': label,
        'confidence': confidence,
      };
    } catch (e) {
      Logger.log('SCENE: _processSegmentationOutput - error: $e');
      return {'label': 'unknown', 'confidence': 0.0};
    }
  }

  String _getClassLabel(int classId) {
    const Map<int, String> VOC_CLASSES = {
      0: 'background',
      1: 'aeroplane',
      2: 'bicycle',
      3: 'bird',
      4: 'boat',
      5: 'bottle',
      6: 'bus',
      7: 'car',
      8: 'cat',
      9: 'chair',
      10: 'cow',
      11: 'dining_table',
      12: 'dog',
      13: 'horse',
      14: 'motorbike',
      15: 'person',
      16: 'potted_plant',
      17: 'sheep',
      18: 'sofa',
      19: 'train',
      20: 'tv_monitor',
    };

    return VOC_CLASSES[classId] ?? 'unknown_object';
  }

  String _createFallbackDescription(String sceneLabel, double confidence) {
    String cleanLabel = sceneLabel.replaceAll('_', ' ');

    Map<String, String> descriptions = {
      'person': 'una persona',
      'car': 'un automóvil',
      'chair': 'una silla',
      'sofa': 'un sofá',
      'dining_table': 'una mesa de comedor',
      'tv_monitor': 'un televisor o monitor',
      'bottle': 'una botella',
      'potted_plant': 'una planta',
      'dog': 'un perro',
      'cat': 'un gato',
      'bicycle': 'una bicicleta',
      'bus': 'un autobús',
      'train': 'un tren',
    };

    String baseDescription = descriptions[cleanLabel] ?? 'Detecto: $cleanLabel';

    if(confidence < 0.15) {
      return "No puedo identificar nada en concreto.";
    }
    if (confidence > 0.5) {
      return 'Hay ${descriptions[sceneLabel]} en frente.';
    } else if (confidence > 0.3) {
      return 'Parece haber ${descriptions[sceneLabel]} frente a ti.';
    } else {
      return 'Posiblemente hay ${descriptions[sceneLabel]} en frente, pero no estoy muy segura.';
    }
  }

  double exp(double x) {
    const double e = 2.718281828459045;
    return pow(e, x).toDouble();
  }

  double pow(double base, double exponent) {
    if (exponent == 0) return 1.0;
    double result = 1.0;
    int exp = exponent.abs().toInt();
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return exponent < 0 ? 1.0 / result : result;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _isInitialized = false;
    await Logger.log('SCENE: dispose');
  }
}
