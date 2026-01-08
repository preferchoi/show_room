import 'dart:collection';
import 'dart:typed_data' as td;

import 'package:flutter/foundation.dart';

import '../../features/detection/domain/detection_result.dart';
import '../../features/detection/infrastructure/detection_repository.dart';
import '../../features/history/domain/detection_capture.dart';
import '../../features/history/domain/detected_item.dart';
import '../../features/history/domain/detection_session.dart';
import '../../features/history/infrastructure/history_repository.dart';

class AppState extends ChangeNotifier {
  static const int maxDetectionHistory = 200;

  AppState(
    this._detectionRepository, {
    HistoryRepository? historyRepository,
    this.confidenceThreshold = 0.25,
    this.modelPath = 'assets/models/yolo11n.tflite',
  }) : _historyRepository = historyRepository ?? InMemoryHistoryRepository();

  final DetectionRepository _detectionRepository;
  final HistoryRepository _historyRepository;

  SceneDetectionResult? currentScene;
  String? selectedObjectId;
  final ListQueue<DetectedObject> _detectionHistory = ListQueue<DetectedObject>();
  List<DetectionSession> get detectionSessions => _historyRepository.sessions;
  List<DetectionCapture> get detectionCaptures => _historyRepository.captures;
  List<DetectedObject> get detectionHistory => _detectionHistory.toList(growable: false);

  bool detectionReady = false;
  bool detectionInitializing = false;
  String? detectionInitError;
  Future<bool>? _detectionInitFuture;

  double confidenceThreshold;
  String modelPath;

  Future<void> updateDetections(td.Uint8List imageBytes) async {
    final result = await _detectionRepository.detect(imageBytes);
    currentScene = result;
    _detectionHistory.addAll(result.objects);
    _trimDetectionHistory();
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

  Future<bool> ensureDetectionReady() async {
    if (detectionReady) return true;
    if (detectionInitializing && _detectionInitFuture != null) {
      return _detectionInitFuture!;
    }

    detectionInitializing = true;
    detectionInitError = null;
    notifyListeners();

    final future = _initializeDetection();
    _detectionInitFuture = future;
    return future;
  }

  void _trimDetectionHistory() {
    while (_detectionHistory.length > maxDetectionHistory) {
      _detectionHistory.removeFirst();
    }
  }

  Future<SceneDetectionResult> detectLive(td.Uint8List imageBytes) async {
    return _detectionRepository.detect(imageBytes);
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

  void addCapture(DetectionCapture capture) {
    _historyRepository.addCapture(capture);
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

  Future<bool> _initializeDetection() async {
    try {
      await _detectionRepository.init();
      detectionReady = true;
      detectionInitializing = false;
      detectionInitError = null;
      notifyListeners();
      return true;
    } catch (err) {
      detectionReady = false;
      detectionInitializing = false;
      detectionInitError = err.toString();
      notifyListeners();
      return false;
    } finally {
      _detectionInitFuture = null;
    }
  }
}
