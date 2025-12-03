import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'detection_repository.dart';
import 'models.dart';

/// Manages the current scene and the selected object.
class SceneState extends ChangeNotifier {
  final DetectionRepository _repository;

  SceneDetectionResult? currentScene;
  String? selectedObjectId;
  Set<String> _targetLabels = const {};

  SceneState(this._repository);

  Set<String> get targetLabels => _targetLabels;

  void setTargetLabels(Set<String> labels) {
    _targetLabels = labels;
    notifyListeners();
  }

  /// Asynchronously loads a scene by delegating to the configured
  /// [DetectionRepository]. The UI remains agnostic of whether detections come
  /// from a mock backend or a real YOLO model.
  Future<void> loadScene(Uint8List imageBytes) async {
    final result = await _repository.detect(
      imageBytes,
      targetLabels: _targetLabels.isEmpty ? null : _targetLabels,
    );
    currentScene = result;
    selectedObjectId = null;
    notifyListeners();
  }

  /// Runs detection again using the currently loaded image, if any.
  Future<void> reloadCurrentScene() async {
    final scene = currentScene;
    if (scene == null) return;

    await loadScene(scene.imageBytes);
  }

  /// Select a specific object by its id and notify listeners.
  void selectObject(String id) {
    selectedObjectId = id;
    notifyListeners();
  }
}
