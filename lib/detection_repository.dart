import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'models.dart';
import 'yolo_service.dart';
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

  Future<_ImageSize?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return _ImageSize(frame.image.width, frame.image.height);
    } catch (_) {
      return null;
    }
  }

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
    final Uint8List sceneBytes = imageBytes.isNotEmpty ? imageBytes : sampleBytes;
    final _ImageSize imageSize =
        await _decodeImageSize(sceneBytes) ?? const _ImageSize(sampleImageWidth, sampleImageHeight);
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
      imageBytes: sceneBytes,
      width: imageSize.width,
      height: imageSize.height,
      objects: objects,
    );
  }
}

class _ImageSize {
  const _ImageSize(this.width, this.height);

  final int width;
  final int height;
}

/// YOLO-backed implementation that delegates to [YoloService].
///
/// Notes:
/// - Keep [useMockDetection] in main.dart enabled while validating model
///   assets and runtime performance on target devices.
class YoloDetectionRepository implements DetectionRepository {
  final YoloService _service;

  YoloDetectionRepository(this._service);

  @override
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    return _service.detect(imageBytes);
  }
}
