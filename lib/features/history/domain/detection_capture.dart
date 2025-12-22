class DetectionCapture {
  const DetectionCapture({
    required this.timestamp,
    required this.originalImagePath,
    required this.detectionImagePath,
    required this.summary,
  });

  final String timestamp;
  final String originalImagePath;
  final String detectionImagePath;
  final String summary;
}
