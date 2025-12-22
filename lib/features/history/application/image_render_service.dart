import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../detection/domain/detection_result.dart';

Future<Uint8List> drawTimestampWatermark({
  required Uint8List originalBytes,
  required String timestampText,
}) async {
  final image = await _decodeImage(originalBytes);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  _drawTimestamp(canvas, image, timestampText);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(image.width, image.height);
  final pngBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}

Future<Uint8List> drawDetectionsOverlay({
  required Uint8List originalBytes,
  required String timestampText,
  required List<DetectedObject> detections,
}) async {
  final image = await _decodeImage(originalBytes);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  _drawDetections(canvas, image, detections);
  _drawTimestamp(canvas, image, timestampText);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(image.width, image.height);
  final pngBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

void _drawTimestamp(ui.Canvas canvas, ui.Image image, String text) {
  const padding = 12.0;
  const fontSize = 24.0;
  final paragraph = _buildParagraph(
    text,
    maxWidth: image.width.toDouble(),
    fontSize: fontSize,
    color: const ui.Color(0xFFFFFFFF),
  );

  final textWidth = paragraph.maxIntrinsicWidth;
  final textHeight = paragraph.height;
  final left = (image.width - textWidth - padding * 2)
      .clamp(padding, image.width.toDouble());
  final top = (image.height - textHeight - padding * 2)
      .clamp(padding, image.height.toDouble());
  final rect = ui.Rect.fromLTWH(
    left,
    top,
    textWidth + padding * 2,
    textHeight + padding * 2,
  );
  final backgroundPaint = ui.Paint()..color = const ui.Color(0xAA000000);

  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8)),
    backgroundPaint,
  );
  canvas.drawParagraph(
    paragraph,
    ui.Offset(rect.left + padding, rect.top + padding),
  );
}

void _drawDetections(
  ui.Canvas canvas,
  ui.Image image,
  List<DetectedObject> detections,
) {
  const labelPadding = 6.0;
  const fontSize = 22.0;
  const strokeWidth = 2.5;
  final maxLabelWidth = image.width.toDouble();

  for (final detection in detections) {
    final color = _colorForLabel(detection.label);
    final rectPaint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRect(detection.bbox, rectPaint);

    final labelText = detection.label;
    final paragraph = _buildParagraph(
      labelText,
      maxWidth: maxLabelWidth,
      fontSize: fontSize,
      color: const ui.Color(0xFFFFFFFF),
    );

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;
    final maxLeft = image.width - textWidth - labelPadding * 2;
    final left = detection.bbox.left
        .clamp(0.0, maxLeft > 0 ? maxLeft : 0.0);
    final top = (detection.bbox.top - textHeight - labelPadding * 2).clamp(
      0.0,
      image.height.toDouble(),
    );

    final backgroundRect = ui.Rect.fromLTWH(
      left,
      top,
      textWidth + labelPadding * 2,
      textHeight + labelPadding * 2,
    );

    final backgroundPaint = ui.Paint()
      ..color = const ui.Color(0xB3000000);

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(backgroundRect, const ui.Radius.circular(6)),
      backgroundPaint,
    );
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        backgroundRect.left + labelPadding,
        backgroundRect.top + labelPadding,
      ),
    );
  }
}

ui.Paragraph _buildParagraph(
  String text, {
  required double maxWidth,
  required double fontSize,
  required ui.Color color,
}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    ),
  )..pushStyle(ui.TextStyle(color: color, fontSize: fontSize));

  builder.addText(text);
  final paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
  return paragraph;
}

ui.Color _colorForLabel(String label) {
  final hue = label.hashCode % 360;
  return ui.HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.5).toColor();
}
