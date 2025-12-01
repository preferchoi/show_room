import 'dart:typed_data';
import 'dart:ui';

/// Binary segmentation mask for a detected object.
class MaskData {
  /// Width of the mask grid (in pixels of the mask, not the original image).
  final int width;

  /// Height of the mask grid (in pixels of the mask, not the original image).
  final int height;

  /// Binary mask data in row-major order.
  /// Each entry is 0 or 1 (or 0/255; any non-zero is treated as inside).
  final Uint8List data;

  /// The bounding box of this mask in the original image coordinate space.
  /// The mask grid corresponds to this rect.
  final Rect bbox;

  const MaskData({
    required this.width,
    required this.height,
    required this.data,
    required this.bbox,
  });

  /// Hit test in original image coordinates.
  /// Returns true if the point (in original image coordinates) is inside
  /// the non-zero region of the mask.
  bool hitTest(Offset imagePoint) {
    // If the point lies outside the mask's bounding box, it cannot be inside.
    if (!bbox.contains(imagePoint)) return false;

    // Map the image coordinate into mask grid coordinates [0, width/height).
    final double u = (imagePoint.dx - bbox.left) / bbox.width;
    final double v = (imagePoint.dy - bbox.top) / bbox.height;

    int px = (u * width).floor();
    int py = (v * height).floor();

    // Clamp to valid range.
    px = px.clamp(0, width - 1);
    py = py.clamp(0, height - 1);

    final int index = py * width + px;
    if (index < 0 || index >= data.length) return false;

    return data[index] != 0;
  }
}

/// Model representing a single detected object.
class DetectedObject {
  final String id; // Internal identifier
  final String label; // e.g. "chair", "desk"
  final Rect bbox; // Bounding box in original image coordinates
  final MaskData? mask; // Optional segmentation mask

  const DetectedObject({
    required this.id,
    required this.label,
    required this.bbox,
    this.mask,
  });
}

/// Holds a detected scene image and all objects found in it.
class SceneDetectionResult {
  final Uint8List imageBytes; // Original image data
  final int width; // Original image width
  final int height; // Original image height
  final List<DetectedObject> objects;

  const SceneDetectionResult({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.objects,
  });
}
