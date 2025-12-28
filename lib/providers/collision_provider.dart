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
  final TtsService _tts_service = TtsService();

  bool _isMonitoring = false;
  DepthResult? _lastResult;
  Timer? _monitoringTimer;
  bool _isRunningInference = false; // avoid overlapping runs

  bool get isMonitoring => _isMonitoring;
  DepthResult? get lastResult => _lastResult;
  bool get hasCollisionRisk => _lastResult?.hasCollision ?? false;

  Future<void> initialize() async {
    await _depthService.initialize();
  }

  Future<void> startMonitoring(Function captureImageCallback) async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    notifyListeners();

    // Reduce frequency and avoid overlapping inferences
    _monitoringTimer = Timer.periodic(Duration(milliseconds: 800), (timer) async {
      if (!_isMonitoring) return;
      if (_isRunningInference) return; // skip if previous inference not finished
      _isRunningInference = true;
      try {
        Uint8List? imageBytes = await captureImageCallback();
        if (imageBytes != null) {
          _lastResult = await _depthService.estimateDepth(imageBytes);
          if (_lastResult!.hasCollision) {
            await _hapticService.vibrateCollisionAlert();
            await _tts_service.speak('Cuidado, riesgo de colision!');
          }
          notifyListeners();
        }
      } catch (e) {
        // keep short: use debugPrint so it doesn't block
        debugPrint('Error en monitoreo: $e');
      } finally {
        _isRunningInference = false;
      }
    });
  }

  // Single-shot capture method
  Future<void> captureOnce(Function captureImageCallback) async {
    if (_isRunningInference) {
      debugPrint('Inference already running - skipping single capture.');
      return;
    }

    _isRunningInference = true;
    try {
      Uint8List? imageBytes = await captureImageCallback();
      if (imageBytes != null) {
        _lastResult = await _depthService.estimateDepth(imageBytes);
        if (_lastResult!.hasCollision) {
          await _hapticService.vibrateCollisionAlert();
          await _tts_service.speak('Cuidado, riesgo de colision!');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in single capture: $e');
    } finally {
      _isRunningInference = false;
    }
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;
    _hapticService.stopVibration();
    _tts_service.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _depthService.dispose();
    super.dispose();
  }
}
