import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class LivePersonPreview extends StatelessWidget {
  const LivePersonPreview({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.personBox,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final Rect? personBox;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = min(
          constraints.maxWidth / imageWidth,
          constraints.maxHeight / imageHeight,
        );
        final displayWidth = imageWidth * scale;
        final displayHeight = imageHeight * scale;
        final horizontalOffset = (constraints.maxWidth - displayWidth) / 2;
        final verticalOffset = (constraints.maxHeight - displayHeight) / 2;

        Rect? scaledBox;
        if (personBox != null) {
          scaledBox = Rect.fromLTWH(
            personBox!.left * scale + horizontalOffset,
            personBox!.top * scale + verticalOffset,
            personBox!.width * scale,
            personBox!.height * scale,
          );
        }

        return Stack(
          children: [
            Center(
              child: Image.memory(
                imageBytes,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
              ),
            ),
            if (scaledBox != null)
              Positioned(
                left: scaledBox.left,
                top: scaledBox.top,
                width: scaledBox.width,
                height: scaledBox.height,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.greenAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'person',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
