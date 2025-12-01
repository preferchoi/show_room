import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Built-in sample image encoded as base64 to keep the mock/demo flow
/// completely offline. The decoded image is 600x400 pixels and matches the
/// mock bounding boxes in [MockDetectionRepository].
const String sampleImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAlgAAAGQCAIAAAD9V4nPAAAF/ElEQVR4nO3VMQ0AMAzAsPJHNhDjssHoEUsGkC9z7gOArFkvAIBFRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkPYBezx9WRmhllgAAAAASUVORK5CYII=';

const int sampleImageWidth = 600;
const int sampleImageHeight = 400;

/// Supported image sources. The sample keeps the mock/demo flow offline while
/// gallery/camera rely on platform plugins.
enum ImageSourceType {
  sample,
  gallery,
  camera,
}

abstract class ImageSourceProvider {
  Future<Uint8List> loadImage(ImageSourceType sourceType);
}

/// Default provider that supports the built-in sample image and platform image
/// pickers (gallery/camera) via the image_picker plugin.
class DefaultImageSourceProvider implements ImageSourceProvider {
  DefaultImageSourceProvider({ImagePicker? imagePicker})
      : _picker = imagePicker ?? ImagePicker();

  final ImagePicker _picker;
  Uint8List? _cachedSample;

  @override
  Future<Uint8List> loadImage(ImageSourceType sourceType) async {
    switch (sourceType) {
      case ImageSourceType.sample:
        return _loadSample();
      case ImageSourceType.gallery:
        await _ensureGalleryPermission();
        return _pickImage(ImageSource.gallery);
      case ImageSourceType.camera:
        await _ensurePermission(Permission.camera);
        return _pickImage(ImageSource.camera);
    }
  }

  Future<Uint8List> _loadSample() async {
    if (_cachedSample != null) return _cachedSample!;
    _cachedSample = base64Decode(sampleImageBase64);
    return _cachedSample!;
  }

  Future<Uint8List> _pickImage(ImageSource source) async {
    final XFile? result = await _picker.pickImage(source: source, requestFullMetadata: false);
    if (result == null) {
      throw const ImageSourceException('이미지 선택이 취소되었어요.');
    }

    final Uint8List bytes = await result.readAsBytes();
    if (bytes.isEmpty) {
      throw const ImageSourceException('선택된 이미지가 비어있어요.');
    }

    return bytes;
  }

  List<Permission> get _galleryPermissions {
    if (Platform.isIOS) return <Permission>[Permission.photos];
    if (Platform.isAndroid) {
      return <Permission>[Permission.photos, Permission.storage];
    }
    return <Permission>[Permission.photos];
  }

  Future<void> _ensurePermission(Permission permission) async {
    final status = await _requestPermission(permission);
    if (_isGranted(status)) return;

    _throwPermissionDenied(status);
  }

  Future<void> _ensureGalleryPermission() async {
    for (final Permission permission in _galleryPermissions) {
      final status = await _requestPermission(permission);
      if (_isGranted(status)) return;

      if (_isTerminalDenial(status)) {
        _throwPermissionDenied(status);
      }
    }

    _throwPermissionDenied(PermissionStatus.denied);
  }

  Future<PermissionStatus> _requestPermission(Permission permission) {
    return permission.request();
  }

  bool _isGranted(PermissionStatus status) {
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  bool _isTerminalDenial(PermissionStatus status) {
    return status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted;
  }

  Never _throwPermissionDenied(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        throw StateError('Permission unexpectedly granted');
      case PermissionStatus.denied:
        throw const ImageSourceException(
          '권한이 거부되어 이미지를 불러올 수 없어요. 설정에서 권한을 허용한 뒤 다시 시도해주세요.',
        );
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
        throw const ImageSourceException(
          '권한이 제한되어 이미지를 불러올 수 없어요. 설정에서 사진 접근을 허용해주세요.',
        );
      case PermissionStatus.provisional:
        // Not expected for these permissions, but keep for exhaustive switches.
        throw const ImageSourceException(
          '권한을 확인할 수 없어요. 설정에서 사진 접근을 허용한 뒤 다시 시도해주세요.',
        );
    }
  }
}

class ImageSourceException implements Exception {
  const ImageSourceException(this.message);
  final String message;

  @override
  String toString() => message;
}
