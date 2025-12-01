import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'object_button.dart';
import 'scene_state.dart';

/// Displays the detected scene image with overlayed interactive regions.
class SceneViewPage extends StatelessWidget {
  const SceneViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sceneState = context.watch<SceneState>();
    final scene = sceneState.currentScene;

    if (scene == null) {
      return const Scaffold(
        body: Center(child: Text('No scene loaded yet')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scene viewer')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate how the original image will be scaled when fitted inside
          // the available space using BoxFit.contain semantics.
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
              // Background image fitted to the available space.
              Center(
                child: Image.memory(
                  scene.imageBytes,
                  width: displayWidth,
                  height: displayHeight,
                  fit: BoxFit.contain,
                ),
              ),
              // Overlay all detected objects scaled into the fitted image space.
              ...scene.objects.map((object) {
                final scaledLeft = object.bbox.left * scale + horizontalOffset;
                final scaledTop = object.bbox.top * scale + verticalOffset;
                final scaledWidth = object.bbox.width * scale;
                final scaledHeight = object.bbox.height * scale;
                final isSelected = sceneState.selectedObjectId == object.id;

                return Positioned(
                  left: scaledLeft,
                  top: scaledTop,
                  width: scaledWidth,
                  height: scaledHeight,
                  child: ObjectButton(
                    object: object,
                    isSelected: isSelected,
                    onTap: () {
                      sceneState.selectObject(object.id);
                      _showObjectSheet(context, object);
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showObjectSheet(BuildContext context, DetectedObject object) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  object.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${object.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text('What is this object? (placeholder)'),
                const SizedBox(height: 8),
                const Text('Search for similar items (placeholder)'),
              ],
            ),
          ),
        );
      },
    );
  }
}
