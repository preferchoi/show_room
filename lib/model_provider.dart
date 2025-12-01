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
    return Interpreter.fromAsset('models/yolo11n.tflite');
  }
}
