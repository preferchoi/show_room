import '../domain/detected_item.dart';
import '../domain/detection_capture.dart';
import '../domain/detection_session.dart';

abstract class HistoryRepository {
  List<DetectionSession> get sessions;
  List<DetectionCapture> get captures;

  void addSession(DetectionSession session);
  void addDetectedItem(DetectedItem item);
  void addCapture(DetectionCapture capture);
}

class InMemoryHistoryRepository implements HistoryRepository {
  final List<DetectionSession> _sessions = [];
  final List<DetectionCapture> _captures = [];

  @override
  List<DetectionSession> get sessions => List.unmodifiable(_sessions);

  @override
  List<DetectionCapture> get captures => List.unmodifiable(_captures);

  @override
  void addSession(DetectionSession session) {
    _sessions.add(session);
  }

  @override
  void addDetectedItem(DetectedItem item) {
    final session = _ensureLatestSession();
    session.items.add(item);
  }

  @override
  void addCapture(DetectionCapture capture) {
    _captures.add(capture);
  }

  DetectionSession _ensureLatestSession() {
    if (_sessions.isEmpty) {
      final session = DetectionSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        items: [],
        startedAt: DateTime.now(),
      );
      _sessions.add(session);
    }
    return _sessions.last;
  }
}
