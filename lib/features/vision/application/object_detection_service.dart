import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../domain/vision_result.dart';

/// Mobile object-detection adapter for the live camera stream.
///
/// This reports 2-D labels and bounding boxes only. It intentionally does not
/// infer metres, free space, stairs, holes, or crossing safety.
final class ObjectDetectionService {
  ObjectDetectionService()
      : _detector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: DetectionMode.stream,
            classifyObjects: true,
            multipleObjects: true,
          ),
        );

  final ObjectDetector _detector;
  bool _busy = false;

  Future<VisionResult?> process(CameraImage image, CameraDescription camera) async {
    if (_busy) return null;
    _busy = true;
    try {
      final input = _toInputImage(image, camera);
      if (input == null) return null;
      final objects = await _detector.processImage(input);
      return VisionResult(
        detections: [
          for (final object in objects)
            for (final label in object.labels)
              VisionDetection(
                label: label.text,
                confidence: label.confidence,
                boundingBox: object.boundingBox,
              ),
        ],
        depthMeters: null,
        source: 'Android ML Kit 2-D object detection',
      );
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    if (!Platform.isAndroid || image.planes.length != 1) return null;
    final plane = image.planes.first;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || format != InputImageFormat.nv21) return null;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotation(camera.sensorOrientation),
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotation(int degrees) {
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> close() async {
    _detector.close();
  }
}
