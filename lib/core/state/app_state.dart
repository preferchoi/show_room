import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../features/detection/domain/detection_result.dart';
import '../../features/detection/infrastructure/detection_repository.dart';
import '../../features/history/domain/detected_item.dart';
import '../../features/history/domain/detection_session.dart';
import '../../features/history/infrastructure/history_repository.dart';

class AppState extends ChangeNotifier {
  AppState(
    this._detectionRepository, {
    HistoryRepository? historyRepository,
    this.confidenceThreshold = 0.25,
    this.modelPath = 'assets/models/yolo11n.tflite',
  }) : _historyRepository = historyRepository ?? HistoryRepository();

  final DetectionRepository _detectionRepository;
  final HistoryRepository _historyRepository;

  SceneDetectionResult? currentScene;
  String? selectedObjectId;
  final List<DetectedObject> detectionHistory = [];
  List<DetectionSession> get detectionSessions => _historyRepository.sessions;

  double confidenceThreshold;
  String modelPath;

  Future<void> updateDetections(Uint8List imageBytes) async {
    final result = await _detectionRepository.detect(imageBytes);
    currentScene = result;
    detectionHistory.addAll(result.objects);
    _historyRepository.addSession(
      DetectionSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        items: result.objects
            .map(
              (object) => DetectedItem(
                object: object,
                detectedAt: DateTime.now(),
              ),
            )
            .toList(),
        startedAt: DateTime.now(),
      ),
    );
    selectedObjectId = null;
    notifyListeners();
  }

  Future<void> reloadCurrentScene() async {
    final scene = currentScene;
    if (scene == null) return;

    await updateDetections(scene.imageBytes);
  }

  void addSession(DetectionSession session) {
    _historyRepository.addSession(session);
    notifyListeners();
  }

  void selectObject(String id) {
    selectedObjectId = id;
    notifyListeners();
  }

  void setConfidenceThreshold(double value) {
    confidenceThreshold = value;
    notifyListeners();
  }

  void setModelPath(String value) {
    modelPath = value;
    notifyListeners();
  }
}
