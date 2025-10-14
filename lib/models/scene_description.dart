class SceneDescription {
  final String rawLabel;
  final double confidence;
  final String naturalDescription;
  final DateTime timestamp;

  SceneDescription({
    required this.rawLabel,
    required this.confidence,
    required this.naturalDescription,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHighConfidence => confidence > 0.7;
  bool get isValid => rawLabel != 'unknown' && confidence > 0.3;

  String get confidenceLevel {
    if (confidence > 0.8) return 'alta';
    if (confidence > 0.6) return 'media';
    if (confidence > 0.4) return 'baja';
    return 'muy baja';
  }

  @override
  String toString() {
    return 'Scene: $rawLabel (${(confidence * 100).toStringAsFixed(1)}%)\n'
        'Description: $naturalDescription';
  }

  Map<String, dynamic> toJson() {
    return {
      'rawLabel': rawLabel,
      'confidence': confidence,
      'naturalDescription': naturalDescription,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SceneDescription.fromJson(Map<String, dynamic> json) {
    return SceneDescription(
      rawLabel: json['rawLabel'] as String,
      confidence: json['confidence'] as double,
      naturalDescription: json['naturalDescription'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}