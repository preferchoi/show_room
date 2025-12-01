import 'package:flutter/foundation.dart';

import 'models.dart';

/// Manages the current scene and the selected object.
class SceneState extends ChangeNotifier {
  SceneDetectionResult? currentScene;
  String? selectedObjectId;

  /// Update the current scene and notify listeners so UI can refresh.
  void setScene(SceneDetectionResult scene) {
    currentScene = scene;
    selectedObjectId = null;
    notifyListeners();
  }

  /// Select a specific object by its id and notify listeners.
  void selectObject(String id) {
    selectedObjectId = id;
    notifyListeners();
  }
}
