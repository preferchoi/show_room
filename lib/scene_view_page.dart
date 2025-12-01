import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'image_source_provider.dart';
import 'label_localizer.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'object_button.dart';
import 'scene_state.dart';

/// Displays the detected scene image with overlayed interactive regions.
class SceneViewPage extends StatefulWidget {
  const SceneViewPage({
    super.key,
    this.imageSourceProvider,
  });

  final ImageSourceProvider? imageSourceProvider;

  @override
  State<SceneViewPage> createState() => _SceneViewPageState();
}

class _SceneViewPageState extends State<SceneViewPage> {
  late final ImageSourceProvider _imageSourceProvider;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _imageSourceProvider = widget.imageSourceProvider ?? DefaultImageSourceProvider();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final sceneState = context.watch<SceneState>();
    final scene = sceneState.currentScene;

    final labelLocalizer = LabelLocalizer();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.sceneViewerTitle ?? 'Scene viewer'),
        actions: [
          IconButton(
            tooltip: '재실행',
            onPressed: _isLoading || scene == null
                ? null
                : () async {
                    await _rerunDetection(sceneState);
                  },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '갤러리 불러오기',
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadFromSource(ImageSourceType.gallery);
                  },
            icon: const Icon(Icons.photo_library_outlined),
          ),
          IconButton(
            tooltip: '카메라로 촬영',
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadFromSource(ImageSourceType.camera);
                  },
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: scene == null
                ? Center(
                    child: Text(localizations?.noSceneLoaded ?? 'No scene loaded yet'),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate how the original image will be scaled when fitted inside
                      // the available space using BoxFit.contain semantics.
                      final scale = min(
                        constraints.maxWidth / scene.width,
                        constraints.maxHeight / scene.height,
                      );
                      final displayWidth = scene.width * scale;
                      final displayHeight = scene.height * scale;
                      final horizontalOffset =
                          (constraints.maxWidth - displayWidth) / 2;
                      final verticalOffset =
                          (constraints.maxHeight - displayHeight) / 2;

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
                            final scaledLeft =
                                object.bbox.left * scale + horizontalOffset;
                            final scaledTop = object.bbox.top * scale + verticalOffset;
                            final scaledWidth = object.bbox.width * scale;
                            final scaledHeight = object.bbox.height * scale;
                            final isSelected =
                                sceneState.selectedObjectId == object.id;

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
                                  _showObjectSheet(
                                    context,
                                    object,
                                    labelLocalizer.localize(
                                      object.label,
                                      context,
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFromSource(ImageSourceType sourceType) async {
    await _runDetection(() => _imageSourceProvider.loadImage(sourceType));
  }

  Future<void> _rerunDetection(SceneState state) async {
    await _runDetection(() async {
      final scene = state.currentScene;
      if (scene == null) return Uint8List(0);
      return scene.imageBytes;
    },
        onInvalidBytesMessage: '감지할 이미지가 없어요.');
  }

  Future<void> _runDetection(
    Future<Uint8List> Function() bytesLoader, {
    String? onInvalidBytesMessage,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await bytesLoader();
      if (bytes.isEmpty) {
        if (onInvalidBytesMessage != null) _showError(onInvalidBytesMessage);
        return;
      }
      await context.read<SceneState>().loadScene(bytes);
    } on ImageSourceException catch (err) {
      _showError(err.message);
    } catch (err, stackTrace) {
      debugPrint('Failed to load image: $err\n$stackTrace');
      _showError('이미지를 불러오지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showObjectSheet(
    BuildContext context,
    DetectedObject object,
    String localizedLabel,
  ) {
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
                  localizedLabel,
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
