import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
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
    for (int i = 0; i < _interpreter!.getOutputTensorCount(); i++) {
      final shape = _interpreter!.getOutputTensor(i).shape;
      // ignore: avoid_print
      print('Output tensor $i shape: $shape');
    }

    // Load labels.
    final String rawLabels = await rootBundle.loadString('assets/models/labels.txt');
    _labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();

    // init() must be awaited once before calling detect().
  }

  /// Runs detection on a single image and returns bounding boxes in the
  /// original image coordinate space.
  Future<SceneDetectionResult> detect(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw StateError('YoloService.init() must be called before detect().');
    }

    final _PreprocessResult prep = _preprocess(imageBytes);

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

  _PreprocessResult _preprocess(Uint8List imageBytes) {
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
    final img.Image letterboxed = img.Image(
      width: _inputWidth,
      height: _inputHeight,
    );
    img.fill(letterboxed, img.getColor(114, 114, 114));
    img.copyInto(letterboxed, resized, dstX: padX, dstY: padY);

    // Convert to Float32 input tensor [1, H, W, C].
    final Float32List inputBuffer =
        Float32List(_inputWidth * _inputHeight * _inputChannels);

    for (int y = 0; y < _inputHeight; y++) {
      for (int x = 0; x < _inputWidth; x++) {
        final int pixel = letterboxed.getPixel(x, y);
        final int offset = (y * _inputWidth + x) * _inputChannels;
        final double r = img.getRed(pixel).toDouble();
        final double g = img.getGreen(pixel).toDouble();
        final double b = img.getBlue(pixel).toDouble();

        // YOLO11 exports expect float RGB input normalized to [0, 1]. No
        // additional mean/std offset is required for the default Ultralytics
        // export.
        inputBuffer[offset + 0] = r / 255.0;
        if (_inputChannels > 1) inputBuffer[offset + 1] = g / 255.0;
        if (_inputChannels > 2) inputBuffer[offset + 2] = b / 255.0;
      }
    }

    return _PreprocessResult(
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
    _PreprocessResult prep,
  ) {
    // The parsing below assumes an output shape like [1, num_predictions, values]
    // where values = 4 bbox + 1 objectness + num_classes. Adjust as needed for
    // your YOLO11n export if the layout differs.
    if (outputShape.length < 3) {
      throw StateError('Unexpected output shape: $outputShape');
    }

    final bool valuesLast = outputShape[2] <= outputShape[1];
    final int numPredictions = valuesLast ? outputShape[1] : outputShape[2];
    final int valuesPerPrediction = valuesLast ? outputShape[2] : outputShape[1];

    double readValue(int predictionIndex, int valueIndex) {
      if (valuesLast) {
        final int baseIndex = predictionIndex * valuesPerPrediction;
        return rawOutput[baseIndex + valueIndex];
      }
      final int baseIndex = valueIndex * numPredictions;
      return rawOutput[baseIndex + predictionIndex];
    }

    final List<_RawDetection> candidates = [];
    for (int i = 0; i < numPredictions; i++) {
      final double xCenter = readValue(i, 0);
      final double yCenter = readValue(i, 1);
      final double width = readValue(i, 2);
      final double height = readValue(i, 3);
      final double objectness = readValue(i, 4);

      // Class scores start at index 5.
      final int numClasses = valuesPerPrediction - 5;
      if (numClasses <= 0) continue;
      double bestClassScore = -double.infinity;
      int bestClassIndex = -1;
      for (int c = 0; c < numClasses; c++) {
        final double classScore = readValue(i, 5 + c);
        if (classScore > bestClassScore) {
          bestClassScore = classScore;
          bestClassIndex = c;
        }
      }

      final double confidence = objectness * bestClassScore;
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
}

class _PreprocessResult {
  _PreprocessResult({
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
