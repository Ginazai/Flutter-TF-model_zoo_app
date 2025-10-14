import 'package:flutter/services.dart';

class HapticService {
  Future<bool> vibrateCollisionAlert() async {
    try {
      HapticFeedback.heavyImpact();
      return true;
    } catch (e) {
      print("Error al proveer feedback: $e");
      return false;
    }
  }

  Future<void> stopVibration() async {
    try {
      // Simulate stopping vibration (no direct API for stopping vibration)
      HapticFeedback.lightImpact();
    } catch (e) {
      print("Error al detener la vibración.");
    }
  }
}