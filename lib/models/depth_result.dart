class DepthResult {
  final bool hasCollision;
  final double minDistance;
  final List<List<double>>? depthMap;
  final DateTime timestamp;

  DepthResult({
    required this.hasCollision,
    required this.minDistance,
    this.depthMap,
  }) : timestamp = DateTime.now();

  // Para debugging
  @override
  String toString() {
    return 'DepthResult(collision: $hasCollision, distance: ${minDistance.toStringAsFixed(2)}m)';
  }
}