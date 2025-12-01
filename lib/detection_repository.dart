import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'models.dart';
import 'yolo_seg_service.dart';
import 'image_source_provider.dart';

/// Abstraction between the UI layer and any detection backend (mock or YOLO).
abstract class DetectionRepository {
  Future<SceneDetectionResult> detect(Uint8List imageBytes);
}

/// Mock implementation that always returns a bundled sample image and a small
/// set of hardcoded bounding boxes. This keeps the UI working end-to-end
/// without relying on a real TFLite model or device-specific hardware.
class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository();

  Uint8List? _cachedBytes;

  Future<Uint8List> _loadSampleBytes() async {
    if (_cachedBytes != null) return _cachedBytes!;
    // Decode the embedded base64 image instead of depending on an external
    // asset. This guarantees the mock flow works offline and in tests.
    _cachedBytes = base64Decode(sampleImageBase64);
    return _cachedBytes!;
  }

  @override
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    final Uint8List sampleBytes = await _loadSampleBytes();
    // Coordinates are defined against the 600x400 sample image (see
    // [sampleImageWidth]/[sampleImageHeight] constants).
    const objects = [
      DetectedObject(
        id: 'desk_1',
        label: 'Desk',
        bbox: Rect.fromLTWH(80, 180, 200, 140),
      ),
      DetectedObject(
        id: 'chair_1',
        label: 'Chair',
        bbox: Rect.fromLTWH(320, 200, 120, 140),
      ),
      DetectedObject(
        id: 'plant_1',
        label: 'Plant',
        bbox: Rect.fromLTWH(480, 100, 70, 120),
      ),
    ];

    return SceneDetectionResult(
      imageBytes: sampleBytes,
      width: sampleImageWidth,
      height: sampleImageHeight,
      objects: objects,
    );
  }
}

/// YOLO-backed implementation that delegates to [YoloSegService].
///
/// Notes:
/// - Keep [useMockDetection] in main.dart enabled while validating model
///   assets and runtime performance on target devices.
class YoloSegDetectionRepository implements DetectionRepository {
  final YoloSegService _service;

  YoloSegDetectionRepository(this._service);

  @override
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    return _service.detect(imageBytes);
  }
}
