import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../detection/domain/detection_result.dart';
import 'object_button.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.scene,
    required this.selectedObjectId,
    required this.onObjectTap,
  });

  final SceneDetectionResult scene;
  final String? selectedObjectId;
  final void Function(DetectedObject) onObjectTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = min(
          constraints.maxWidth / scene.width,
          constraints.maxHeight / scene.height,
        );
        final displayWidth = scene.width * scale;
        final displayHeight = scene.height * scale;
        final horizontalOffset = (constraints.maxWidth - displayWidth) / 2;
        final verticalOffset = (constraints.maxHeight - displayHeight) / 2;

        return Stack(
          children: [
            Center(
              child: Image.memory(
                scene.imageBytes,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
              ),
            ),
            ...scene.objects.map((object) {
              final scaledLeft = object.bbox.left * scale + horizontalOffset;
              final scaledTop = object.bbox.top * scale + verticalOffset;
              final scaledWidth = object.bbox.width * scale;
              final scaledHeight = object.bbox.height * scale;
              final isSelected = selectedObjectId == object.id;

              return Positioned(
                left: scaledLeft,
                top: scaledTop,
                width: scaledWidth,
                height: scaledHeight,
                child: ObjectButton(
                  object: object,
                  isSelected: isSelected,
                  onTap: () => onObjectTap(object),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
