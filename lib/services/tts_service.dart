import 'package:flutter_tts/flutter_tts.dart';
import '../utils/logger.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      await Logger.log('TTS: initialize - starting');

      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
      await Logger.log('TTS: initialize - finished');
    } catch (e) {
      await Logger.log('TTS: initialize - error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await Logger.log('TTS: converting output to speech - "$text"');
      await _flutterTts.speak(text);
      await Logger.log('TTS: converted output to speech');
    } catch (e) {
      await Logger.log('TTS: speak - error: $e');
    }
  }

  // NUEVO: Método para detener el TTS
  Future<void> stop() async {
    try {
      await Logger.log('TTS: stopping speech');
      await _flutterTts.stop();
      await Logger.log('TTS: speech stopped');
    } catch (e) {
      await Logger.log('TTS: stop - error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await Logger.log('TTS: dispose - starting');
      await _flutterTts.stop();
      _isInitialized = false;
      await Logger.log('TTS: dispose - finished');
    } catch (e) {
      await Logger.log('TTS: dispose - error: $e');
    }
  }
}