import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'detection_repository.dart';
import 'models.dart';

/// Manages the current scene and the selected object.
class SceneState extends ChangeNotifier {
  final DetectionRepository _repository;

  SceneDetectionResult? currentScene;
  String? selectedObjectId;

  SceneState(this._repository);

  /// Asynchronously loads a scene by delegating to the configured
  /// [DetectionRepository]. The UI remains agnostic of whether detections come
  /// from a mock backend or a real YOLO model.
  Future<void> loadScene(Uint8List imageBytes) async {
    final result = await _repository.detect(imageBytes);
    currentScene = result;
    selectedObjectId = null;
    notifyListeners();
  }

  /// Select a specific object by its id and notify listeners.
  void selectObject(String id) {
    selectedObjectId = id;
    notifyListeners();
  }
}
