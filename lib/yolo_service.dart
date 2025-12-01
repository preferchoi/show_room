import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'models.dart';
import 'model_provider.dart';

/// Service that loads a YOLO11n detection model and runs inference on-device.
///
/// Call [init] once before invoking [detect]. This service keeps the
/// interpreter alive for reuse.
class YoloService {
  YoloService._internal({ModelProvider? modelProvider})
      : _modelProvider = modelProvider ?? AssetModelProvider();

  static final YoloService instance = YoloService._internal();

  Interpreter? _interpreter;
  ModelProvider _modelProvider;
  List<String> _labels = [];

  int _inputWidth = 0;
  int _inputHeight = 0;
  int _inputChannels = 0;

  double _confidenceThreshold = 0.25;
  double _iouThreshold = 0.45;

  // TODO: Fill in model-specific metadata such as number of classes or anchors
  // if your YOLO11n export requires it. The parsing code assumes a standard
  // detection head layout; adjust as necessary for your model.

  /// Allows swapping the interpreter provider (e.g., downloaded model) before
  /// initialization.
  void setModelProvider(ModelProvider provider) {
    if (_interpreter != null) {
      throw StateError('Cannot swap model provider after initialization.');
    }
    _modelProvider = provider;
  }

  @visibleForTesting
  void debugConfigure({
    required int inputWidth,
    required int inputHeight,
    int inputChannels = 3,
    double? confidenceThreshold,
    double? iouThreshold,
    List<String>? labels,
  }) {
    _inputWidth = inputWidth;
    _inputHeight = inputHeight;
    _inputChannels = inputChannels;
    _confidenceThreshold = confidenceThreshold ?? _confidenceThreshold;
    _iouThreshold = iouThreshold ?? _iouThreshold;
    if (labels != null) {
      _labels = normalizeLabels(labels.join('\n'));
    }
  }

  @visibleForTesting
  List<DetectedObject> parseDetectionsForTest(
    List<double> rawOutput,
    List<int> outputShape,
    PreprocessResult prep,
  ) {
    return _parseDetections(rawOutput, outputShape, prep);
  }

  /// Normalizes the label file contents by trimming whitespace and removing
  /// empty lines.
  @visibleForTesting
  static List<String> normalizeLabels(String rawLabels) {
    return rawLabels
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Loads the TFLite model and labels. Safe to call multiple times; the
  /// interpreter is created only once.
  Future<void> init() async {
    if (_interpreter != null) return;

    // Asset path must match pubspec.yaml configuration. Alternate providers
    // (e.g., downloaded files) can be injected via [setModelProvider] without
    // changing the rest of the pipeline.
    _interpreter = await _modelProvider.loadInterpreter();
    assert(_interpreter != null, 'Failed to create TFLite interpreter');

    // Capture input tensor shape: [1, height, width, channels].
    final Tensor inputTensor = _interpreter!.getInputTensor(0);
    final List<int> inputShape = inputTensor.shape;
    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];
    _inputChannels = inputShape[3];

    // Optionally inspect output tensor shapes to understand your model layout.
    // For YOLO-style detectors this is often [1, num_predictions, values_per_pred].
    // TODO: Confirm the actual shape for your YOLO11n TFLite export.
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Interpreter unexpectedly null after initialization.');
    }

    final outputTensors = interpreter.getOutputTensors();
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      // ignore: avoid_print
      print('Output tensor $i shape: $shape');
    }

    // Load labels.
    final String rawLabels = await rootBundle.loadString('assets/models/labels.txt');
    _labels = normalizeLabels(rawLabels);

    // init() must be awaited once before calling detect().
  }

  /// Runs detection on a single image and returns bounding boxes in the
  /// original image coordinate space.
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw StateError('YoloService.init() must be called before detect().');
    }

    final PreprocessResult prep = _preprocess(imageBytes);

    // Prepare output buffer based on the first output tensor shape.
    final Tensor outputTensor = _interpreter!.getOutputTensor(0);
    final List<int> outputShape = outputTensor.shape;
    final int outputElementCount =
        outputShape.fold<int>(1, (previous, dim) => previous * dim);
    final List<double> outputBuffer = List<double>.filled(outputElementCount, 0);

    // Run inference.
    _interpreter!.run(prep.inputBuffer, outputBuffer);

    final List<DetectedObject> detections = _parseDetections(
      outputBuffer,
      outputShape,
      prep,
    );

    return SceneDetectionResult(
      imageBytes: imageBytes,
      width: prep.originalWidth,
      height: prep.originalHeight,
      objects: detections,
    );
  }

  PreprocessResult _preprocess(Uint8List imageBytes) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Unable to decode image bytes');
    }

    final int originalWidth = decoded.width;
    final int originalHeight = decoded.height;

    // Letterbox resize while keeping aspect ratio. YOLO exports expect padding
    // filled with mid-gray (114) and coordinates relative to the padded image.
    final double scale =
        min(_inputWidth / originalWidth, _inputHeight / originalHeight);
    final int resizedWidth = (originalWidth * scale).round();
    final int resizedHeight = (originalHeight * scale).round();

    final img.Image resized = img.copyResize(
      decoded,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final int padX = ((_inputWidth - resizedWidth) / 2).floor();
    final int padY = ((_inputHeight - resizedHeight) / 2).floor();
    final paddingColor = img.ColorRgb8(114, 114, 114);
    final img.Image letterboxed = img.Image(
      width: _inputWidth,
      height: _inputHeight,
    );
    img.fill(letterboxed, color: paddingColor);
    img.compositeImage(letterboxed, resized, dstX: padX, dstY: padY);

    // Convert to Float32 input tensor [1, H, W, C].
    final Float32List inputBuffer =
        Float32List(_inputWidth * _inputHeight * _inputChannels);

    for (int y = 0; y < _inputHeight; y++) {
      for (int x = 0; x < _inputWidth; x++) {
        final img.Pixel pixel = letterboxed.getPixel(x, y);
        final int offset = (y * _inputWidth + x) * _inputChannels;
        final double r = pixel.r.toDouble();
        final double g = pixel.g.toDouble();
        final double b = pixel.b.toDouble();

        // YOLO11 exports expect float RGB input normalized to [0, 1]. No
        // additional mean/std offset is required for the default Ultralytics
        // export.
        inputBuffer[offset + 0] = r / 255.0;
        if (_inputChannels > 1) inputBuffer[offset + 1] = g / 255.0;
        if (_inputChannels > 2) inputBuffer[offset + 2] = b / 255.0;
      }
    }

    return PreprocessResult(
      inputBuffer: inputBuffer,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      scale: scale,
      padX: padX.toDouble(),
      padY: padY.toDouble(),
    );
  }

  List<DetectedObject> _parseDetections(
    List<double> rawOutput,
    List<int> outputShape,
    PreprocessResult prep,
  ) {
    // YOLO11 exports typically emit a detection head shaped [1, 8400, 84]
    // (values last) or [1, 84, 8400] (values first) where values =
    // [cx, cy, w, h, class_scores...]. Some variants include an objectness
    // probability between the box coordinates and class scores. The parsing
    // below adapts to both layouts and validates the label count when labels
    // are available.
    if (outputShape.length != 3 || outputShape[0] != 1) {
      throw StateError('Unexpected output shape: $outputShape');
    }

    final int dim1 = outputShape[1];
    final int dim2 = outputShape[2];
    final layouts = <({int predictions, int values, bool valuesFirst})>[
      (predictions: dim1, values: dim2, valuesFirst: false),
      (predictions: dim2, values: dim1, valuesFirst: true),
    ];

    ({int predictions, int values, bool valuesFirst})? selectedLayout;
    for (final layout in layouts) {
      if (_labels.isNotEmpty &&
          (layout.values == 4 + _labels.length ||
              layout.values == 5 + _labels.length)) {
        selectedLayout = layout;
        break;
      }
    }

    selectedLayout ??=
        layouts.where((layout) => layout.values >= 4).fold<({int predictions, int values, bool valuesFirst})?>(
              null,
              (current, layout) =>
                  current == null || layout.predictions > current.predictions
                      ? layout
                      : current,
            );
    selectedLayout ??= layouts.first;

    final int numPredictions = selectedLayout.predictions;
    final int valuesPerPrediction = selectedLayout.values;
    final bool valuesFirst = selectedLayout.valuesFirst;

    if (numPredictions * valuesPerPrediction > rawOutput.length) {
      throw StateError(
        'Output buffer length ${rawOutput.length} is insufficient for shape $outputShape.',
      );
    }

    double readValue(int predictionIndex, int valueIndex) {
      if (!valuesFirst) {
        final int baseIndex = predictionIndex * valuesPerPrediction;
        return rawOutput[baseIndex + valueIndex];
      }
      final int baseIndex = valueIndex * numPredictions;
      return rawOutput[baseIndex + predictionIndex];
    }

    final bool hasObjectnessHint =
        _labels.isNotEmpty && valuesPerPrediction == 5 + _labels.length;
    final bool noObjectnessHint =
        _labels.isNotEmpty && valuesPerPrediction == 4 + _labels.length;
    bool hasObjectness = hasObjectnessHint;
    if (!hasObjectnessHint && !noObjectnessHint) {
      hasObjectness = valuesPerPrediction.isOdd && valuesPerPrediction > 5;
    }
    if (noObjectnessHint) {
      hasObjectness = false;
    }
    final int classOffset = hasObjectness ? 5 : 4;
    final int numClasses = valuesPerPrediction - classOffset;

    if (numClasses <= 0) {
      throw StateError('Unable to infer class count from output shape: $outputShape');
    }
    if (_labels.isNotEmpty && _labels.length != numClasses) {
      throw StateError(
        'Label count (${_labels.length}) does not match model classes ($numClasses).',
      );
    }

    final List<_RawDetection> candidates = [];
    for (int i = 0; i < numPredictions; i++) {
      final double xCenter = readValue(i, 0);
      final double yCenter = readValue(i, 1);
      final double width = readValue(i, 2);
      final double height = readValue(i, 3);

      final double objectnessLogit = hasObjectness ? readValue(i, 4) : 0.0;
      double bestClassLogit = -double.infinity;
      int bestClassIndex = -1;
      for (int c = 0; c < numClasses; c++) {
        final double classScore = readValue(i, classOffset + c);
        if (classScore > bestClassLogit) {
          bestClassLogit = classScore;
          bestClassIndex = c;
        }
      }

      final double objectnessProb = hasObjectness ? _sigmoid(objectnessLogit) : 1.0;
      final double bestClassProb = _sigmoid(bestClassLogit);
      final double confidence = objectnessProb * bestClassProb;
      if (confidence < _confidenceThreshold) continue;

      // YOLO exports return center-x/y and width/height relative to the
      // letterboxed image. Some exports emit normalized [0, 1] coordinates;
      // others use absolute pixels. Normalize to the padded input first, then
      // remove padding and unscale back to the original image space.
      final bool normalizedBbox =
          xCenter <= 1.0 && yCenter <= 1.0 && width <= 1.0 && height <= 1.0;
      final double boxX = normalizedBbox ? xCenter * _inputWidth : xCenter;
      final double boxY = normalizedBbox ? yCenter * _inputHeight : yCenter;
      final double boxW = normalizedBbox ? width * _inputWidth : width;
      final double boxH = normalizedBbox ? height * _inputHeight : height;

      double xMin = boxX - boxW / 2 - prep.padX;
      double yMin = boxY - boxH / 2 - prep.padY;
      double xMax = boxX + boxW / 2 - prep.padX;
      double yMax = boxY + boxH / 2 - prep.padY;

      xMin = (xMin / prep.scale).clamp(0, prep.originalWidth.toDouble());
      yMin = (yMin / prep.scale).clamp(0, prep.originalHeight.toDouble());
      xMax = (xMax / prep.scale).clamp(0, prep.originalWidth.toDouble());
      yMax = (yMax / prep.scale).clamp(0, prep.originalHeight.toDouble());

      if (xMax <= xMin || yMax <= yMin) continue;

      final Rect rect = Rect.fromLTRB(xMin, yMin, xMax, yMax);

      final String label =
          (bestClassIndex >= 0 && bestClassIndex < _labels.length)
              ? _labels[bestClassIndex]
              : 'class_$bestClassIndex';

      candidates.add(
        _RawDetection(
          bbox: rect,
          label: label,
          score: confidence,
        ),
      );
    }

    final List<_RawDetection> filtered = _nonMaxSuppression(
      candidates,
      _iouThreshold,
    );

    final List<DetectedObject> objects = [];
    for (int i = 0; i < filtered.length; i++) {
      final _RawDetection det = filtered[i];
      objects.add(
        DetectedObject(
          id: 'obj_$i',
          label: det.label,
          bbox: det.bbox,
        ),
      );
    }

    return objects;
  }

  List<_RawDetection> _nonMaxSuppression(
    List<_RawDetection> detections,
    double iouThreshold,
  ) {
    detections.sort((a, b) => b.score.compareTo(a.score));
    final List<_RawDetection> results = [];

    for (final _RawDetection det in detections) {
      bool shouldKeep = true;
      for (final _RawDetection kept in results) {
        final double overlap = _iou(det.bbox, kept.bbox);
        if (overlap > iouThreshold) {
          shouldKeep = false;
          break;
        }
      }
      if (shouldKeep) {
        results.add(det);
      }
    }

    return results;
  }

  double _iou(Rect a, Rect b) {
    final double intersectionArea =
        max(0, min(a.right, b.right) - max(a.left, b.left)) *
            max(0, min(a.bottom, b.bottom) - max(a.top, b.top));
    final double unionArea = a.width * a.height + b.width * b.height - intersectionArea;
    if (unionArea == 0) return 0;
    return intersectionArea / unionArea;
  }

  double _sigmoid(double x) => 1 / (1 + exp(-x));
}

class PreprocessResult {
  const PreprocessResult({
    required this.inputBuffer,
    required this.originalWidth,
    required this.originalHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final Float32List inputBuffer;
  final int originalWidth;
  final int originalHeight;
  final double scale;
  final double padX;
  final double padY;
}

class _RawDetection {
  _RawDetection({
    required this.bbox,
    required this.label,
    required this.score,
  });

  final Rect bbox;
  final String label;
  final double score;
}

// Example usage:
//
// await YoloService.instance.init();
// final result = await YoloService.instance.detect(imageBytes);
// print('Detected ${result.objects.length} objects');
// for (final obj in result.objects) {
//   print('${obj.label} at ${obj.bbox}');
// }
