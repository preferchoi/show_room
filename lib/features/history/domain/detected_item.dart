import '../../detection/domain/detection_result.dart';

class DetectedItem {
  const DetectedItem({required this.object, required this.detectedAt});

  final DetectedObject object;
  final DateTime detectedAt;
}
