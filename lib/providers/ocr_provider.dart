import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/ocr_service.dart';
import '../services/tts_service.dart';
import '../models/ocr_result.dart';

class OCRProvider with ChangeNotifier {
  final OCRService _ocrService = OCRService();
  final TtsService _ttsService = TtsService();

  bool _isProcessing = false;
  OCRResult? _lastResult;
  String? _errorMessage;

  // GETTERS
  bool get isProcessing => _isProcessing;
  OCRResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;

  // INITIALIZE
  Future<void> initialize() async {
    try {
      final success = await _ocrService.initialize();
      if (!success) {
        _errorMessage = 'Failed to initialize OCR service';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error during initialization: $e';
      notifyListeners();
    }
  }

  // PROCESS IMAGE
  Future<void> processImage(Uint8List imageBytes) async {
    _isProcessing = true;
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // Perform OCR
      String rawText = await _ocrService.recognizeText(imageBytes);

      if (rawText.isEmpty) {
        _errorMessage = 'No text detected in image';
        await _ttsService.speak('No se detectó texto');
      } else {
        // Create result with ML Kit confidence (default to high confidence if text found)
        _lastResult = OCRResult(
          rawText: rawText,
          confidence: 0.9,
        );

        // Speak the recognized text
        await _ttsService.speak(_lastResult!.rawText);
      }
    } catch (e) {
      _errorMessage = 'Error processing OCR: $e';
      print('Error procesando OCR: $e');
      await _ttsService.speak('Error al procesar la imagen');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // NUEVO: Método para detener el TTS
  Future<void> stopSpeaking() async {
    await _ttsService.stop();
  }

  @override
  void dispose() {
    // Detener el TTS antes de destruir el provider
    _ttsService.stop();
    _ocrService.dispose();
    super.dispose();
  }
}