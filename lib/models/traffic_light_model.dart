class TrafficLightResult {
  final int predictedClass;
  final String className;
  final double confidence;
  final List<double> directionPoints; // [x1, y1, x2, y2]
  final List<double> allProbabilities; // Softmax probabilities for all 5 classes
  
  TrafficLightResult({
    required this.predictedClass,
    required this.className,
    required this.confidence,
    required this.directionPoints,
    required this.allProbabilities,
  });

  // Traffic light class names
  static const Map<int, String> classNames = {
    0: 'Red',
    1: 'Green',
    2: 'Countdown Green',
    3: 'Countdown Blank',
    4: 'None',
  };

  // Check if it's safe to cross (Green or Countdown Green)
  bool get isSafeToCross => predictedClass == 1 || predictedClass == 2;
  
  // Check if should stop (Red)
  bool get shouldStop => predictedClass == 0;
  
  // Check if no traffic light detected
  bool get noTrafficLight => predictedClass == 4;

  @override
  String toString() {
    return 'TrafficLightResult(class: $className, confidence: ${confidence.toStringAsFixed(1)}%, safe: $isSafeToCross)';
  }
}