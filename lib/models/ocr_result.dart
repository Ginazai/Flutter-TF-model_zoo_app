class OCRResult {
  final String rawText;
  final double confidence;
  final DateTime timestamp;

  OCRResult({
    required this.rawText,
    required this.confidence,
  }) : timestamp = DateTime.now();

  bool get isValid => confidence > 0.5;
}