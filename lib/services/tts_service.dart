import 'package:flutter_tts/flutter_tts.dart';
import '../utils/logger.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _tts.setLanguage("es-ES");
    _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    await Logger.log('TTS: converting output to speech - "$text"');
    try {
      await _tts.speak(text);
      await Logger.log('TTS: converted output to speech');
    } catch (e) {
      await Logger.log('TTS: speak error - $e');
    }
  }

  Future<void> stop() async {
    await Logger.log('TTS: stop - starting');
    try {
      await _tts.stop();
      await Logger.log('TTS: stop - finished');
    } catch (e) {
      await Logger.log('TTS: stop error - $e');
    }
  }
}