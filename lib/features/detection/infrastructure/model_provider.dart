import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Abstraction for supplying a TFLite interpreter. Today we only support an
/// asset-backed model, but a downloaded model can be injected later without
/// modifying [YoloService].
abstract class ModelProvider {
  Future<Interpreter> loadInterpreter();
}

class AssetModelProvider implements ModelProvider {
  @override
  Future<Interpreter> loadInterpreter() async {
    // The asset path must be kept in sync with pubspec.yaml.
    const String assetPath = 'assets/models/yolo11n.tflite';

    final ByteData modelBytes = await rootBundle.load(assetPath);
    final buffer = modelBytes.buffer.asUint8List();

    // A guard to avoid confusing runtime errors if the asset is replaced with
    // a placeholder text file.
    const String placeholderSignature = 'Placeholder model file.';
    final String asciiPrefix = String.fromCharCodes(
      buffer.take(placeholderSignature.length),
    );
    if (asciiPrefix == placeholderSignature) {
      throw StateError(
        'A placeholder model file was found at $assetPath. Replace it with the '
        'YOLO11n TensorFlow Lite binary before enabling on-device detection.',
      );
    }

    return Interpreter.fromBuffer(buffer);
  }
}
