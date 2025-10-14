class OCRResult {
  final String rawText;
  final String correctedText;
  final double confidence;
  final DateTime timestamp;

  OCRResult({
    required this.rawText,
    required this.correctedText,
    required this.confidence,
  }) : timestamp = DateTime.now();

  bool get isValid => confidence > 0.5 && correctedText.isNotEmpty;
}