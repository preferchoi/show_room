import 'dart:convert';
import 'dart:typed_data';

/// Built-in sample image encoded as base64 to keep the mock/demo flow
/// completely offline. The decoded image is 600x400 pixels and matches the
/// mock bounding boxes in [MockDetectionRepository].
const String sampleImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAlgAAAGQCAIAAAD9V4nPAAAF/ElEQVR4nO3VMQ0AMAzAsPJHNhDjssHoEUsGkC9z7gOArFkvAIBFRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkPYBezx9WRmhllgAAAAASUVORK5CYII=';

const int sampleImageWidth = 600;
const int sampleImageHeight = 400;

/// Supported image sources. Only [ImageSourceType.sample] is implemented today
/// to keep the mock/demo flow simple.
enum ImageSourceType {
  sample,
  gallery,
  camera,
}

abstract class ImageSourceProvider {
  Future<Uint8List> loadImage(ImageSourceType sourceType);
}

/// Default provider that can be extended to support gallery/camera later while
/// keeping the sample-based path stable for mocks and demos.
class SampleImageSourceProvider implements ImageSourceProvider {
  Uint8List? _cachedSample;

  @override
  Future<Uint8List> loadImage(ImageSourceType sourceType) async {
    if (sourceType != ImageSourceType.sample) {
      // Extension point: wire up image_picker / camera plugins later without
      // breaking the current flow.
      throw UnimplementedError('Only the sample image is implemented for now.');
    }

    if (_cachedSample != null) return _cachedSample!;
    _cachedSample = base64Decode(sampleImageBase64);
    return _cachedSample!;
  }
}
