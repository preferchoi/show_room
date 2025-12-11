import '../domain/detected_item.dart';
import '../domain/detection_session.dart';

class HistoryRepository {
  final List<DetectionSession> _sessions = [];

  List<DetectionSession> get sessions => List.unmodifiable(_sessions);

  void addSession(DetectionSession session) {
    _sessions.add(session);
  }

  void addDetectedItem(DetectedItem item) {
    final session = _ensureLatestSession();
    session.items.add(item);
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
