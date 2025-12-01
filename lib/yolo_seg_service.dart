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
  ///   - assets/models/yolo11n-seg.tflite
  ///   - assets/models/labels.txt
  /// ```
  Future<void> init() async {
    if (_interpreter != null) return;

    // Load interpreter from bundled asset.
    _interpreter = await Interpreter.fromAsset('models/yolo11n-seg.tflite');

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
    final outputs = _interpreter!.getOutputTensors();
    if (outputs.isNotEmpty) {
      final detectionShape = outputs.first.shape;
      if (detectionShape.length == 3) {
        final int channels = detectionShape[2];
        // Estimate number of masks and classes based on prototype dimensions.
        final int? estimatedMaskDim = outputs.length > 1 && outputs[1].shape.length == 4
            ? outputs[1].shape[1]
            : _maskCoefficientDim;
        _maskCoefficientDim ??= estimatedMaskDim;
        if (_maskCoefficientDim != null) {
          final int possibleClasses = channels - 4 - _maskCoefficientDim!;
          // Some exports include an objectness score in addition to class logits.
          final int withObjness = possibleClasses - 1;
          if (_labels.isNotEmpty && (_labels.length == possibleClasses || _labels.length == withObjness)) {
            _numClasses = _labels.length;
          } else if (possibleClasses > 0) {
            _numClasses = possibleClasses > withObjness ? withObjness : possibleClasses;
          }
        }
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
    if (detectionHead is! List || detectionHead.isEmpty) {
      return [];
    }

    final List predictions =
        detectionHead.length == 1 && detectionHead.first is List ? detectionHead.first as List : detectionHead;

    final detections = <_RawDetection>[];
    final int maskDim = _maskCoefficientDim ?? 0;

    for (final prediction in predictions) {
      if (prediction is! List) continue;
      if (prediction.length < 4) continue;

      final values = prediction.map((e) => (e as num).toDouble()).toList();

      final int availableMaskDim = maskDim > 0 ? maskDim : max(0, values.length - 4 - _numClasses);
      final int maskStart = max(4, values.length - availableMaskDim);
      final int availableClassSlots = max(0, maskStart - 4);

      double objectness = 1.0;
      int classStart = 4;
      int classCount = availableClassSlots;

      if (_numClasses > 0 && availableClassSlots == _numClasses + 1) {
        // Layout with objectness followed by class logits.
        objectness = _sigmoid(values[4]);
        classStart = 5;
        classCount = _numClasses;
      } else if (_numClasses > 0 && availableClassSlots >= _numClasses) {
        classCount = _numClasses;
      }

      // Find best class using sigmoid-activated logits.
      int bestClass = -1;
      double bestClassScore = 0;
      for (int i = 0; i < classCount; i++) {
        final int idx = classStart + i;
        if (idx >= values.length) break;
        final double prob = _sigmoid(values[idx]);
        if (prob > bestClassScore) {
          bestClassScore = prob;
          bestClass = i;
        }
      }

      final double confidence = objectness * bestClassScore;
      if (confidence < _confidenceThreshold || bestClass == -1) continue;

      // Bounding box in input scale (cx, cy, w, h).
      final double cx = values[0];
      final double cy = values[1];
      final double w = values[2];
      final double h = values[3];

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
      if (maskStart < values.length) {
        maskCoefficients = values.sublist(maskStart);
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

    // Convert detection bbox from input resolution to prototype grid resolution.
    final double scaleX = maskWidth / _inputWidth;
    final double scaleY = maskHeight / _inputHeight;
    final int x0 = (bboxOnInput.left * scaleX).floor().clamp(0, maskWidth - 1).toInt();
    final int y0 = (bboxOnInput.top * scaleY).floor().clamp(0, maskHeight - 1).toInt();
    final int x1 = (bboxOnInput.right * scaleX).ceil().clamp(x0 + 1, maskWidth).toInt();
    final int y1 = (bboxOnInput.bottom * scaleY).ceil().clamp(y0 + 1, maskHeight).toInt();

    final int cropWidth = x1 - x0;
    final int cropHeight = y1 - y0;
    if (cropWidth <= 0 || cropHeight <= 0) return null;

    final Uint8List binaryMask = Uint8List(cropWidth * cropHeight);

    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        double sum = 0;
        for (int k = 0; k < effectiveDim; k++) {
          sum += proto[k][y][x] * maskCoefficients[k];
        }
        final double prob = _sigmoid(sum);
        final int localIndex = (y - y0) * cropWidth + (x - x0);
        binaryMask[localIndex] = prob > 0.5 ? 255 : 0;
      }
    }

    // Optionally downsample the mask for lighter hit-testing while keeping the same bbox.
    final int targetWidth = min(cropWidth, 128);
    final int targetHeight = min(cropHeight, 128);
    final Uint8List resizedMask = _resizeBinaryMask(binaryMask, cropWidth, cropHeight, targetWidth, targetHeight);

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
