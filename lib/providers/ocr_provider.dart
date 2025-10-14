import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/ocr_service.dart';
import '../services/text_correction_service.dart';
import '../services/tts_service.dart';
import '../models/ocr_result.dart';

class OCRProvider with ChangeNotifier {
  final OCRService _ocrService = OCRService();
  final TextCorrectionService _correctionService = TextCorrectionService();
  final TtsService _ttsService = TtsService();

  bool _isProcessing = false;
  OCRResult? _lastResult;

  // GETTERS
  bool get isProcessing => _isProcessing;
  OCRResult? get lastResult => _lastResult;

  // INICIALIZAR
  Future<void> initialize() async {
    await _correctionService.initialize();
    await _ocrService.initialize();
  }

  // PROCESAR IMAGEN
  Future<void> processImage(Uint8List imageBytes) async {
    _isProcessing = true;
    _lastResult = null;
    notifyListeners();

    try {
      // 1. OCR
      String rawText = await _ocrService.recognizeText(imageBytes);

      // 2. Corrección con BERT
      String correctedText = await _correctionService.correctText(rawText);

      // 3. Crear resultado
      _lastResult = OCRResult(
        rawText: rawText,
        correctedText: correctedText,
        confidence: rawText.isNotEmpty ? 0.8 : 0.0,
      );

      // 4. Leer en voz alta
      if (_lastResult!.isValid) {
        await _ttsService.speak(_lastResult!.correctedText);
      } else {
        await _ttsService.speak('No se detectó texto');
      }
    } catch (e) {
      print('Error procesando OCR: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _correctionService.dispose();
    super.dispose();
  }
}