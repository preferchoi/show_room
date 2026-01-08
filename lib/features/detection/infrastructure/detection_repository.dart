import 'dart:convert' as co;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../camera/infrastructure/image_source_provider.dart';
import '../domain/detection_result.dart';
import 'yolo_service.dart';

/// Abstraction between the UI layer and any detection backend (mock or YOLO).
abstract class DetectionRepository {
  Future<void> init();
  Future<SceneDetectionResult> detect(Uint8List imageBytes);
}

/// Mock implementation that always returns a bundled sample image and a small
/// set of hardcoded bounding boxes. This keeps the UI working end-to-end
/// without relying on a real TFLite model or device-specific hardware.
class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository();

  Uint8List? _cachedBytes;

  Future<_ImageSize?> _decodeImageSize(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final width = image.width;
      final height = image.height;
      return _ImageSize(width, height);
    } catch (_) {
      return null;
    } finally {
      // This decode path is metadata-only; dispose decoded resources here
      // to avoid leaking image/codec handles.
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<Uint8List> _loadSampleBytes() async {
    if (_cachedBytes != null) return _cachedBytes!;
    // Decode the embedded base64 image instead of depending on an external
    // asset. This guarantees the mock flow works offline and in tests.
    _cachedBytes = co.base64Decode(sampleImageBase64);
    return _cachedBytes!;
  }

  @override
  Future<void> init() async {}

  @override
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    final Uint8List sampleBytes = await _loadSampleBytes();
    final Uint8List sceneBytes = imageBytes.isNotEmpty ? imageBytes : sampleBytes;
    final _ImageSize imageSize =
        await _decodeImageSize(sceneBytes) ?? const _ImageSize(sampleImageWidth, sampleImageHeight);

    final double scaleX = imageSize.width / sampleImageWidth;
    final double scaleY = imageSize.height / sampleImageHeight;

    final List<DetectedObject> objects = _sampleObjects
        .map(
          (obj) => obj.toDetected(
            scaleX: scaleX,
            scaleY: scaleY,
          ),
        )
        .toList(growable: false);

    return SceneDetectionResult(
      imageBytes: sceneBytes,
      width: imageSize.width,
      height: imageSize.height,
      objects: objects,
    );
  }
}

class _SampleObject {
  const _SampleObject({
    required this.id,
    required this.label,
    required this.bbox,
  });

  final String id;
  final String label;
  final ui.Rect bbox;

  DetectedObject toDetected({required double scaleX, required double scaleY}) {
    final ui.Rect scaled = ui.Rect.fromLTRB(
      bbox.left * scaleX,
      bbox.top * scaleY,
      bbox.right * scaleX,
      bbox.bottom * scaleY,
    );
    return DetectedObject(
      id: id,
      label: label,
      bbox: scaled,
      confidence: 0.9,
    );
  }
}

// Coordinates are defined against the 600x400 sample image (see
// [sampleImageWidth]/[sampleImageHeight] constants).
const List<_SampleObject> _sampleObjects = [
  _SampleObject(
    id: 'desk_1',
    label: 'Desk',
    bbox: ui.Rect.fromLTWH(80, 180, 200, 140),
  ),
  _SampleObject(
    id: 'chair_1',
    label: 'Chair',
    bbox: ui.Rect.fromLTWH(320, 200, 120, 140),
  ),
  _SampleObject(
    id: 'plant_1',
    label: 'Plant',
    bbox: ui.Rect.fromLTWH(480, 100, 70, 120),
  ),
];

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
  YoloDetectionRepository(this._service);

  final YoloService _service;

  @override
  Future<void> init() async {
    await _service.init();
  }

  @override
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    return _service.detect(imageBytes);
  }
}
