import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'models.dart';

/// A lightweight YOLO segmentation service using tflite_flutter.
///
/// Usage:
/// ```dart
/// await YoloSegService.instance.init();
/// final SceneDetectionResult result = await YoloSegService.instance.detect(imageBytes);
/// ```
///
/// Call [init] once (e.g., before runApp or lazily before first detection)
/// to load the interpreter and labels.
class YoloSegService {
  YoloSegService._internal();

  static final YoloSegService instance = YoloSegService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];

  late int _inputWidth;
  late int _inputHeight;
  late int _inputChannels;

  final double _confidenceThreshold = 0.3;
  final double _iouThreshold = 0.45;

  // Optional model metadata that may be inferred from labels or output tensors.
  int _numClasses = 0;
  // TODO: Populate with the mask coefficient dimension once known for your export.
  int? _maskCoefficientDim;

  bool get isInitialized => _interpreter != null;

  /// Loads the YOLO segmentation model and labels.
  ///
  /// The assets must be declared in pubspec.yaml, e.g.:
  ///
  /// ```yaml
  /// assets:
  ///   - assets/models/yolov8-seg.tflite
  ///   - assets/models/labels.txt
  /// ```
  Future<void> init() async {
    if (_interpreter != null) return;

    // Load interpreter from bundled asset.
    _interpreter = await Interpreter.fromAsset('models/yolov8-seg.tflite');

    // Read input tensor shape to derive expected image size.
    final inputTensor = _interpreter!.getInputTensor(0);
    final List<int> inputShape = inputTensor.shape;
    if (inputShape.length != 4) {
      throw StateError('Unexpected input tensor rank: ${inputShape.length}');
    }
    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];
    _inputChannels = inputShape[3];

    // Load optional labels; if file missing, fall back to empty labels list.
    try {
      final rawLabels = await rootBundle.loadString('assets/models/labels.txt');
      _labels = rawLabels
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } on FlutterError {
      _labels = [];
    }

    _numClasses = _labels.length;

    // Inspect output tensors to understand shapes for detections and prototypes.
    // Typical YOLO-seg exports have:
    // - output 0: detection head => [1, num_predictions, 4 + 1 + num_classes + mask_coeffs]
    // - output 1: mask prototypes => [1, mask_dim, mask_h, mask_w]
    // TODO: Adjust indices and dimensions to match your specific model.
    final outputs = _interpreter!.getOutputTensors();
    if (outputs.length >= 2) {
      final protoShape = outputs[1].shape;
      // Example: [1, mask_dim, mask_h, mask_w]
      if (protoShape.length == 4) {
        _maskCoefficientDim = protoShape[1];
      }
    }
  }

  /// Runs detection on the provided [imageBytes].
  /// Throws if called before [init].
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('YoloSegService.init() must be called before detect().');
    }

    final _PreprocessResult prep = _preprocess(imageBytes);

    // Allocate output buffers based on model outputs.
    // TODO: Adapt the output shapes and data types to your YOLO-seg export.
    // For YOLOv8-seg, one output is usually [batch, num_predictions, (classes+4+1+mask_dim)]
    // and another output for mask prototypes [batch, mask_dim, mask_h, mask_w].
    final outputTensors = interpreter.getOutputTensors();
    final outputs = <int, Object>{};
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      outputs[i] = _zeros(shape);
    }

    // Run inference.
    interpreter.runForMultipleInputs([prep.input], outputs);

    // Parse detections from raw output tensors.
    final Object? detectionHead = outputs[0];
    final Object? maskPrototypes = outputTensors.length > 1 ? outputs[1] : null;

    final detectedObjects = _parseDetections(
      detectionHead,
      maskPrototypes,
      prep.originalWidth,
      prep.originalHeight,
    );

    return SceneDetectionResult(
      imageBytes: imageBytes,
      width: prep.originalWidth,
      height: prep.originalHeight,
      objects: detectedObjects,
    );
  }

  _PreprocessResult _preprocess(Uint8List imageBytes) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Failed to decode input image');
    }

    final originalWidth = decoded.width;
    final originalHeight = decoded.height;

    // Resize to model input size.
    final resized = img.copyResize(decoded, width: _inputWidth, height: _inputHeight);

    // Convert to Float32 input buffer. Adjust normalization if your model differs.
    final inputBuffer = Float32List(_inputWidth * _inputHeight * _inputChannels);
    int idx = 0;
    for (int y = 0; y < _inputHeight; y++) {
      for (int x = 0; x < _inputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final r = img.getRed(pixel) / 255.0;
        final g = img.getGreen(pixel) / 255.0;
        final b = img.getBlue(pixel) / 255.0;
        inputBuffer[idx++] = r;
        inputBuffer[idx++] = g;
        inputBuffer[idx++] = b;
      }
    }

    // Reshape to [1, height, width, channels].
    final input = _reshapeInput(inputBuffer, [1, _inputHeight, _inputWidth, _inputChannels]);

    return _PreprocessResult(
      input: input,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  /// Reshapes a flat Float32List into a nested List structure matching [shape].
  /// This is required because the TFLite interpreter expects properly nested
  /// Dart lists when feeding inputs in pure Dart.
  Object _reshapeInput(Float32List data, List<int> shape) {
    int offset = 0;

    Object build(List<int> dims) {
      if (dims.length == 1) {
        final length = dims.first;
        final list = List<double>.generate(length, (i) => data[offset + i]);
        offset += length;
        return list;
      }
      final length = dims.first;
      final rest = dims.sublist(1);
      return List.generate(length, (_) => build(rest));
    }

    return build(shape);
  }

  /// Creates a nested zero-filled list matching [shape] for output tensors.
  Object _zeros(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0);
    }
    final length = shape.first;
    final rest = shape.sublist(1);
    return List.generate(length, (_) => _zeros(rest));
  }

  List<DetectedObject> _parseDetections(
    Object? detectionHead,
    Object? maskPrototypes,
    int originalWidth,
    int originalHeight,
  ) {
    // TODO: Update parsing logic to match your YOLO seg output tensor format.
    // Example assumption: detectionHead => [1, num_predictions, 4 + 1 + num_classes + mask_coeffs]
    if (detectionHead is! List || detectionHead.isEmpty || detectionHead.first is! List) {
      return [];
    }

    final detections = <_RawDetection>[];

    for (final prediction in detectionHead.first as List) {
      if (prediction is! List) continue;
      if (prediction.length < 6) continue; // Minimal check: x,y,w,h,objectness,class scores...

      // The indices below are model dependent. Replace with actual mapping for your export:
      // [cx, cy, w, h, obj_conf, class_conf_0 ... class_conf_n, mask_coeffs...]
      final double objConf = (prediction[4] as num).toDouble();
      if (objConf < _confidenceThreshold) continue;

      // Find best class.
      int bestClass = 0;
      double bestClassScore = 0;
      final int classCount = _numClasses > 0 ? _numClasses : max(0, prediction.length - 5);
      for (int i = 0; i < classCount; i++) {
        final int idx = 5 + i;
        if (idx >= prediction.length) break;
        final score = (prediction[idx] as num).toDouble();
        if (score > bestClassScore) {
          bestClassScore = score;
          bestClass = i;
        }
      }
      final double confidence = objConf * bestClassScore;
      if (confidence < _confidenceThreshold) continue;

      // Bounding box in input scale (cx, cy, w, h).
      final double cx = (prediction[0] as num).toDouble();
      final double cy = (prediction[1] as num).toDouble();
      final double w = (prediction[2] as num).toDouble();
      final double h = (prediction[3] as num).toDouble();

      final double xMin = cx - w / 2;
      final double yMin = cy - h / 2;
      final double xMax = cx + w / 2;
      final double yMax = cy + h / 2;

      // Scale back to original image coordinates.
      final double scaleX = originalWidth / _inputWidth;
      final double scaleY = originalHeight / _inputHeight;

      final Rect bboxInputSpace = Rect.fromLTRB(xMin, yMin, xMax, yMax);
      final Rect bboxOriginalSpace = Rect.fromLTRB(
        xMin * scaleX,
        yMin * scaleY,
        xMax * scaleX,
        yMax * scaleY,
      );

      final label = (bestClass < _labels.length) ? _labels[bestClass] : 'class_$bestClass';

      List<double>? maskCoefficients;
      // YOLO-seg usually appends mask coefficients after the class scores.
      // TODO: Adjust start index and length based on your export. For YOLOv8-seg
      // it's often at index (5 + num_classes) with length mask_dim.
      final int coeffStart = 5 + classCount;
      if (coeffStart < prediction.length) {
        maskCoefficients = prediction
            .skip(coeffStart)
            .map((e) => (e as num).toDouble())
            .toList();
      }

      detections.add(_RawDetection(
        bboxInputSpace: bboxInputSpace,
        bboxOriginalSpace: bboxOriginalSpace,
        confidence: confidence,
        label: label,
        maskCoefficients: maskCoefficients,
      ));
    }

    final filtered = _nonMaxSuppression(detections, _iouThreshold);

    return filtered.map((d) {
      MaskData? mask;
      if (maskPrototypes != null && d.maskCoefficients != null) {
        mask = _buildMaskForDetection(
          maskCoefficients: d.maskCoefficients!,
          maskPrototypes: maskPrototypes,
          bboxOnInput: d.bboxInputSpace,
          bboxOnOriginal: d.bboxOriginalSpace,
        );
      }

      // Masks are optional. UI code can use object.mask?.hitTest(imagePoint)
      // to provide irregular hit-testing in original image coordinates.
      return DetectedObject(
        id: '${d.label}_${d.confidence.toStringAsFixed(2)}_${d.hashCode}',
        label: d.label,
        bbox: d.bboxOriginalSpace,
        mask: mask,
      );
    }).toList();
  }

  /// Builds a binary [MaskData] for a detection by combining mask coefficients
  /// with the prototype tensor output from the model.
  MaskData? _buildMaskForDetection({
    required List<double> maskCoefficients,
    required Object maskPrototypes,
    required Rect bboxOnInput,
    required Rect bboxOnOriginal,
  }) {
    // TODO: Adapt this implementation to your YOLO-seg export format.
    // Typical flow:
    // 1) maskPrototypes: [1, mask_dim, mask_h, mask_w]
    // 2) Multiply prototypes by maskCoefficients (length == mask_dim).
    // 3) Apply sigmoid to obtain per-pixel probabilities.
    // 4) Optionally crop to bboxOnInput and/or resize to target mask grid.
    // 5) Threshold (e.g., >0.5) to produce binary mask.
    // 6) Map the mask grid's bounding box from input space to original space.

    if (maskCoefficients.isEmpty) return null;

    final proto = _toDoubleCube(maskPrototypes);
    if (proto == null || proto.isEmpty) return null;

    final int maskDim = proto.length;
    final int coeffCount = maskCoefficients.length;
    final int effectiveDim = min(maskDim, coeffCount);
    if (effectiveDim == 0) return null;
    final int maskHeight = proto.first.length;
    final int maskWidth = proto.first.isNotEmpty ? proto.first.first.length : 0;
    if (maskWidth == 0 || maskHeight == 0) return null;

    // Placeholder composition: generate a dummy mask proportional to bbox area.
    // Replace with real prototype * coefficient multiplication for production use.
    final Uint8List binaryMask = Uint8List(maskWidth * maskHeight);
    // Example pseudocode for real mask blending (commented):
    // for y in 0..maskHeight-1:
    //   for x in 0..maskWidth-1:
    //     double sum = 0;
    //     for k in 0..maskDim-1:
    //       sum += proto[k][y][x] * maskCoefficients[k];
    //     final prob = _sigmoid(sum);
    //     binaryMask[y * maskWidth + x] = prob > 0.5 ? 1 : 0;
    // TODO: Uncomment and adapt the above loop when mask dimensions are known.

    // Current placeholder: fill with 1s to cover the bbox area.
    binaryMask.fillRange(0, binaryMask.length, 1);

    // Optionally resize/crop mask to a smaller grid for efficient hit-testing.
    final int targetWidth = min(maskWidth, 64);
    final int targetHeight = min(maskHeight, 64);
    final Uint8List resizedMask = _resizeBinaryMask(binaryMask, maskWidth, maskHeight, targetWidth, targetHeight);

    return MaskData(
      width: targetWidth,
      height: targetHeight,
      data: resizedMask,
      bbox: bboxOnOriginal,
    );
  }

  /// Converts a dynamic nested list (e.g., output tensor) into a 3D list of doubles.
  List<List<List<double>>>? _toDoubleCube(Object tensor) {
    if (tensor is! List || tensor.isEmpty) return null;
    final first = tensor.first;
    if (first is List && first.isNotEmpty && first.first is List) {
      // Shape could be [batch, mask_dim, mask_h, mask_w]; drop batch dimension if present.
      final List source = tensor.length == 1 ? tensor.first as List : tensor as List;
      return source
          .map<List<List<double>>>((dim) =>
              (dim as List).map<List<double>>((row) => (row as List).map((v) => (v as num).toDouble()).toList()).toList())
          .toList();
    }
    return null;
  }

  Uint8List _resizeBinaryMask(
    Uint8List data,
    int width,
    int height,
    int targetWidth,
    int targetHeight,
  ) {
    final img.Image src = img.Image.fromBytes(width: width, height: height, bytes: data.buffer);
    final img.Image resized = img.copyResize(
      src,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.nearest,
    );
    return Uint8List.fromList(resized.getBytes(format: img.Format.luminance));
  }

  double _sigmoid(double x) => 1 / (1 + exp(-x));

  List<_RawDetection> _nonMaxSuppression(List<_RawDetection> detections, double iouThreshold) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <_RawDetection>[];

    for (final det in detections) {
      bool shouldSelect = true;
      for (final kept in selected) {
        final iou = _computeIoU(det.bboxOriginalSpace, kept.bboxOriginalSpace);
        if (iou > iouThreshold) {
          shouldSelect = false;
          break;
        }
      }
      if (shouldSelect) {
        selected.add(det);
      }
    }

    return selected;
  }

  double _computeIoU(Rect a, Rect b) {
    final double intersectionXMin = max(a.left, b.left);
    final double intersectionYMin = max(a.top, b.top);
    final double intersectionXMax = min(a.right, b.right);
    final double intersectionYMax = min(a.bottom, b.bottom);

    final double intersectionWidth = max(0, intersectionXMax - intersectionXMin);
    final double intersectionHeight = max(0, intersectionYMax - intersectionYMin);
    final double intersectionArea = intersectionWidth * intersectionHeight;

    final double unionArea = a.width * a.height + b.width * b.height - intersectionArea;
    if (unionArea == 0) return 0;

    return intersectionArea / unionArea;
  }
}

class _PreprocessResult {
  _PreprocessResult({
    required this.input,
    required this.originalWidth,
    required this.originalHeight,
  });

  final Object input;
  final int originalWidth;
  final int originalHeight;
}

class _RawDetection {
  _RawDetection({
    required this.bboxInputSpace,
    required this.bboxOriginalSpace,
    required this.confidence,
    required this.label,
    this.maskCoefficients,
  });

  final Rect bboxInputSpace;
  final Rect bboxOriginalSpace;
  final double confidence;
  final String label;
  final List<double>? maskCoefficients;
}
