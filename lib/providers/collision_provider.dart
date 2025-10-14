import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/depth_estimation_service.dart';
import '../services/haptic_service.dart';
import '../services/tts_service.dart';
import '../models/depth_result.dart';

class CollisionProvider with ChangeNotifier {
  final DepthEstimationService _depthService = DepthEstimationService();
  final HapticService _hapticService = HapticService();
  final TtsService _ttsService = TtsService();

  bool _isMonitoring = false;
  DepthResult? _lastResult;
  Timer? _monitoringTimer;

  // GETTERS
  bool get isMonitoring => _isMonitoring;
  DepthResult? get lastResult => _lastResult;
  bool get hasCollisionRisk => _lastResult?.hasCollision ?? false;

  // INICIALIZAR (llamar al crear el provider)
  Future<void> initialize() async {
    await _depthService.initialize();
  }

  // INICIAR MONITOREO CONTINUO
  Future<void> startMonitoring(Function captureImageCallback) async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    notifyListeners();

    // Ejecutar cada 500ms
    _monitoringTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      try {
        // Obtener imagen del callback (viene del ESP32Service)
        Uint8List? imageBytes = await captureImageCallback();

        if (imageBytes != null) {
          _lastResult = await _depthService.estimateDepth(imageBytes);

          // Retroalimentación
          if (_lastResult!.hasCollision) {
            await _hapticService.vibrateCollisionAlert();
            await _ttsService.speak('Cuidado, riesgo de colision!'); //centí
          }

          notifyListeners();
        }
      } catch (e) {
        print('Error en monitoreo: $e');
      }
    });
  }

  // DETENER MONITOREO
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;
    _hapticService.stopVibration();
    _ttsService.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _depthService.dispose();
    super.dispose();
  }
}