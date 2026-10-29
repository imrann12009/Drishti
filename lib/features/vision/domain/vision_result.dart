import 'dart:ui';

final class VisionDetection {
  const VisionDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final String label;
  final double confidence;
  final Rect boundingBox;
}

/// Depth is deliberately nullable. A normal phone camera plus 2-D object
/// detection does not establish physical distance or a safe path.
final class VisionResult {
  const VisionResult({
    required this.detections,
    required this.depthMeters,
    required this.source,
  });

  final List<VisionDetection> detections;
  final double? depthMeters;
  final String source;

  bool get hasDepth => depthMeters != null;
}
