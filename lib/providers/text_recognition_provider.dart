import 'package:flutter/foundation.dart';

class TextRecognitionProvider with ChangeNotifier {
  bool _isProcessing = false;
  String? _lastResult;

  bool get isProcessing => _isProcessing;
  String? get lastResult => _lastResult;

  Future<void> captureAndAnalyze(Future<String> Function() captureImage) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final image = await captureImage();
      // Aquí iría la lógica de reconocimiento de texto
      _lastResult = "CALLE PRINCIPAL - NO ESTACIONAR"; // Ejemplo
    } catch (e) {
      _lastResult = "Error: $e";
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
