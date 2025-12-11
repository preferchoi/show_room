import 'detected_item.dart';

class DetectionSession {
  DetectionSession({required this.id, required this.items, required this.startedAt});

  final String id;
  final List<DetectedItem> items;
  final DateTime startedAt;
}
