import '../domain/detected_item.dart';
import '../domain/detection_capture.dart';
import '../domain/detection_session.dart';

class HistoryRepository {
  final List<DetectionSession> _sessions = [];
  final List<DetectionCapture> _captures = [];

  List<DetectionSession> get sessions => List.unmodifiable(_sessions);
  List<DetectionCapture> get captures => List.unmodifiable(_captures);

  void addSession(DetectionSession session) {
    _sessions.add(session);
  }

  void addDetectedItem(DetectedItem item) {
    final session = _ensureLatestSession();
    session.items.add(item);
  }

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
