import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:show_room/yolo_service.dart';

void main() {
  test('normalizeLabels trims whitespace and removes empty entries', () {
    const rawLabels = ' person\ncar\n\n dog  \n';
    final normalized = YoloService.normalizeLabels(rawLabels);

    expect(normalized, ['person', 'car', 'dog']);
  });

  test('parseDetections handles values-last YOLO output without objectness', () {
    final service = YoloService.instance;
    service.debugConfigure(
      inputWidth: 640,
      inputHeight: 640,
      labels: const ['person', 'car', 'dog'],
      confidenceThreshold: 0.2,
    );

    const shape = [1, 2, 7];
    final rawOutput = <double>[
      // Prediction 0
      320, // cx
      320, // cy
      100, // w
      50, // h
      0.1, // class 0
      0.2, // class 1
      0.8, // class 2
      // Prediction 1 (below threshold)
      20,
      20,
      10,
      10,
      0.05,
      0.1,
      0.05,
    ];

    const prep = PreprocessResult(
      inputBuffer: Float32List(0),
      originalWidth: 640,
      originalHeight: 640,
      scale: 1,
      padX: 0,
      padY: 0,
    );

    final detections =
        service.parseDetectionsForTest(rawOutput, shape, prep);

    expect(detections, hasLength(1));
    final detection = detections.single;
    expect(detection.label, 'dog');
    expect(detection.bbox.left, closeTo(270, 1e-3));
    expect(detection.bbox.top, closeTo(295, 1e-3));
    expect(detection.bbox.right, closeTo(370, 1e-3));
    expect(detection.bbox.bottom, closeTo(345, 1e-3));
  });
}
