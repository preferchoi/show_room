import 'dart:typed_data';

import '../infrastructure/image_source_provider.dart';

/// Handles fetching image bytes from different sources for the camera feature.
class CameraController {
  CameraController({ImageSourceProvider? imageSourceProvider})
      : _imageSourceProvider = imageSourceProvider ?? DefaultImageSourceProvider();

  final ImageSourceProvider _imageSourceProvider;

  Future<Uint8List> loadImage(ImageSourceType sourceType) {
    return _imageSourceProvider.loadImage(sourceType);
  }
}
