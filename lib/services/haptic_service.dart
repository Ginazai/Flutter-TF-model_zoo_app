import 'package:flutter/services.dart';
import '../utils/logger.dart';

class HapticService {
  Future<bool> vibrateCollisionAlert() async {
    await Logger.log('HAPTIC: vibrateCollisionAlert - starting');
    try {
      HapticFeedback.heavyImpact();
      await Logger.log('HAPTIC: vibrateCollisionAlert - finished');
      return true;
    } catch (e) {
      await Logger.log('HAPTIC: vibrateCollisionAlert - error: $e');
      return false;
    }
  }

  Future<void> stopVibration() async {
    await Logger.log('HAPTIC: stopVibration - starting');
    try {
      // Simulate stopping vibration (no direct API for stopping vibration)
      HapticFeedback.lightImpact();
      await Logger.log('HAPTIC: stopVibration - finished');
    } catch (e) {
      await Logger.log('HAPTIC: stopVibration - error: $e');
    }
  }
}