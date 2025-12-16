import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/scene_description_service.dart';
import '../services/tts_service.dart';
import '../models/scene_description.dart';

class SceneDetectionProvider with ChangeNotifier {
  final SceneDetectionService _sceneService = SceneDetectionService();
  final TtsService _ttsService = TtsService();

  bool _isProcessing = false;
  bool _isMonitoring = false;
  SceneDescription? _lastResult;
  Timer? _monitoringTimer;

  // History of detections
  final List<SceneDescription> _history = [];
  static const int MAX_HISTORY = 10;

  // GETTERS
  bool get isProcessing => _isProcessing;
  bool get isMonitoring => _isMonitoring;
  SceneDescription? get lastResult => _lastResult;
  List<SceneDescription> get history => List.unmodifiable(_history);
  bool get hasValidResult => _lastResult?.isValid ?? false;

  // INICIALIZAR
  Future<bool> initialize() async {
    try {
      await _sceneService.initialize();
      return true;
    } catch (e) {
      print('Error inicializando SceneDetectionProvider: $e');
      return false;
    }
  }

  // DETECTAR ESCENA (una sola vez)
  Future<void> detectScene(Uint8List imageBytes) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _lastResult = null;
    notifyListeners();

    try {
      // Detectar escena
      _lastResult = await _sceneService.detectScene(imageBytes);

      // Agregar al historial
      _addToHistory(_lastResult!);

      // Leer descripción en voz alta
      await _ttsService.speak(_lastResult!.naturalDescription);
      // if (_lastResult!.isValid) {
      //   await _ttsService.speak(_lastResult!.naturalDescription);
      // } else {
      //   await _ttsService.speak('No pude identificar la escena claramente');
      // }
    } catch (e) {
      print('Error detectando escena: $e');
      await _ttsService.speak('Error al detectar la escena');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // MONITOREO CONTINUO (detecta escena cada X segundos)
  Future<void> startMonitoring(
      Function captureImageCallback, {
        Duration interval = const Duration(seconds: 5),
      }) async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    notifyListeners();

    print('Monitoreo de escena iniciado (cada ${interval.inSeconds}s)');

    _monitoringTimer = Timer.periodic(interval, (timer) async {
      try {
        // Capturar imagen
        Uint8List? imageBytes = await captureImageCallback();

        if (imageBytes != null && !_isProcessing) {
          await _detectSceneQuiet(imageBytes);
        }
      } catch (e) {
        print('Error en monitoreo de escena: $e');
      }
    });
  }

  // Detección silenciosa (sin audio, para monitoreo)
  Future<void> _detectSceneQuiet(Uint8List imageBytes) async {
    _isProcessing = true;

    try {
      final previousScene = _lastResult?.rawLabel;

      _lastResult = await _sceneService.detectScene(imageBytes);
      _addToHistory(_lastResult!);

      // Solo hablar si la escena cambió significativamente
      if (_lastResult!.isValid &&
          _lastResult!.isHighConfidence &&
          _lastResult!.rawLabel != previousScene) {

        await _ttsService.speak(
            'Cambio de escena: ${_lastResult!.naturalDescription}'
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error en detección silenciosa: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // DETENER MONITOREO
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _ttsService.stop();

    print('Monitoreo de escena detenido');
    notifyListeners();
  }

  // OBTENER DESCRIPCIÓN VERBAL DE LA ÚLTIMA ESCENA
  Future<void> repeatLastDescription() async {
    if (_lastResult != null && _lastResult!.isValid) {
      await _ttsService.speak(_lastResult!.naturalDescription);
    } else {
      await _ttsService.speak('No hay ninguna escena detectada');
    }
  }

  // ANÁLISIS DE HISTORIAL
  String getMostFrequentScene() {
    if (_history.isEmpty) return 'unknown';

    Map<String, int> frequency = {};
    for (var scene in _history) {
      frequency[scene.rawLabel] = (frequency[scene.rawLabel] ?? 0) + 1;
    }

    return frequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double getAverageConfidence() {
    if (_history.isEmpty) return 0.0;

    double sum = _history.fold(0.0, (prev, scene) => prev + scene.confidence);
    return sum / _history.length;
  }

  // LIMPIAR HISTORIAL
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  // HELPERS PRIVADOS
  void _addToHistory(SceneDescription scene) {
    _history.insert(0, scene);

    // Mantener solo las últimas MAX_HISTORY detecciones
    if (_history.length > MAX_HISTORY) {
      _history.removeRange(MAX_HISTORY, _history.length);
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _sceneService.dispose();
    _ttsService.stop();
    super.dispose();
  }
}