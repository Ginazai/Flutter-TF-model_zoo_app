import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/traffic_light_service.dart';
import '../services/haptic_service.dart';
import '../services/tts_service.dart';
import '../models/traffic_light_model.dart';

class TrafficLightProvider with ChangeNotifier {
  final TrafficLightService _trafficLightService = TrafficLightService();
  final HapticService _hapticService = HapticService();
  final TtsService _ttsService = TtsService();

  bool _isMonitoring = false;
  TrafficLightResult? _lastResult;
  Timer? _monitoringTimer;
  bool _isRunningInference = false;

  bool get isMonitoring => _isMonitoring;
  TrafficLightResult? get lastResult => _lastResult;
  bool get isProcessing => _isRunningInference;
  
  // Convenience getters for UI
  bool get shouldStop => _lastResult?.shouldStop ?? false;
  bool get isSafeToCross => _lastResult?.isSafeToCross ?? false;
  bool get noTrafficLight => _lastResult?.noTrafficLight ?? false;

  Future<void> initialize() async {
    await _trafficLightService.initialize();
  }

  Future<void> startMonitoring(Function captureImageCallback) async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    notifyListeners();

    // Monitor every 2 seconds to allow inference to complete
    _monitoringTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_isMonitoring) return;
      
      if (_isRunningInference) {
        debugPrint('Skipping frame - previous inference still running');
        return;
      }

      _isRunningInference = true;
      notifyListeners();

      try {
        Uint8List? imageBytes = await captureImageCallback();
        
        if (imageBytes != null && _isMonitoring) {
          final previousResult = _lastResult;
          _lastResult = await _trafficLightService.detect(imageBytes);
          
          // Provide feedback on traffic light state changes
          if (_isMonitoring && previousResult != null) {
            await _handleStateChange(previousResult, _lastResult!);
          } else if (_isMonitoring) {
            // First detection
            await _announceCurrentState(_lastResult!);
          }
          
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error en monitoreo de semáforo: $e');
      } finally {
        _isRunningInference = false;
        notifyListeners();
      }
    });
  }

  // Single-shot detection
  Future<void> detectOnce(Function captureImageCallback) async {
    if (_isRunningInference) {
      debugPrint('Inference already running - skipping single detection.');
      return;
    }

    _isRunningInference = true;
    notifyListeners();

    try {
      Uint8List? imageBytes = await captureImageCallback();
      
      if (imageBytes != null) {
        _lastResult = await _trafficLightService.detect(imageBytes);
        await _announceCurrentState(_lastResult!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in single detection: $e');
    } finally {
      _isRunningInference = false;
      notifyListeners();
    }
  }

  Future<void> _handleStateChange(
    TrafficLightResult previous,
    TrafficLightResult current,
  ) async {
    // Only announce if class changed
    if (previous.predictedClass != current.predictedClass) {
      await _announceCurrentState(current);
    }
  }

  Future<void> _announceCurrentState(TrafficLightResult result) async {
    String message;
    
    switch (result.predictedClass) {
      case 0: // Red
        message = 'Semáforo en rojo. Deténgase.';
        await _hapticService.vibrateCollisionAlert();
        break;
      case 1: // Green
        message = 'Semáforo en verde. Puede cruzar.';
        await _hapticService.vibrateCollisionAlert();
        break;
      case 2: // Countdown Green
        message = 'Semáforo en verde intermitente. Cruce con precaución.';
        await _hapticService.vibrateCollisionAlert();
        break;
      case 3: // Countdown Blank
        message = 'Semáforo intermitente. Precaución.';
        await _hapticService.vibrateCollisionAlert();
        break;
      case 4: // None
        message = 'No se detectó semáforo.';
        break;
      default:
        message = 'Estado desconocido.';
    }
    
    await _ttsService.speak(message);
  }

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
    _trafficLightService.dispose();
    super.dispose();
  }
}