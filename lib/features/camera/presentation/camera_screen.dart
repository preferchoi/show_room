// import 'dart:typed_data';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/state/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/application/camera_controller.dart';
import '../../camera/infrastructure/image_source_provider.dart';
import '../../detection/application/label_localizer.dart';
import '../../detection/domain/detection_result.dart';
import '../../history/application/image_render_service.dart';
import '../../history/domain/detection_capture.dart';
import '../../history/presentation/detection_result_screen.dart';
import 'widgets/detection_overlay.dart';
import 'widgets/live_person_preview.dart';

/// Displays the detected scene image with overlayed interactive regions.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    this.imageSourceProvider,
  });

  final ImageSourceProvider? imageSourceProvider;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late final CameraController _cameraController;
  bool _isLoading = false;
  Rect? _livePersonBox;
  DateTime? _livePersonLastSeenAt;
  DateTime _lastInferTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInferring = false;
  StreamSubscription<Uint8List>? _previewSubscription;
  Uint8List? _livePreviewBytes;
  int? _livePreviewWidth;
  int? _livePreviewHeight;

  static const Duration _holdDuration = Duration(milliseconds: 500);
  static const Duration _liveInferInterval = Duration(milliseconds: 120);
  static const double _livePersonMinConf = 0.35;

  @override
  void initState() {
    super.initState();
    _cameraController =
        CameraController(imageSourceProvider: widget.imageSourceProvider);
    _startLivePreview();
  }

  @override
  void dispose() {
    _previewSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final scene = appState.currentScene;

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
                      await _rerunDetection(appState);
                    },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '갤러리 불러오기',
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadFromSource(
                      ImageSourceType.gallery,
                      openResult: false,
                    );
                  },
            icon: const Icon(Icons.photo_library_outlined),
          ),
          IconButton(
            tooltip: '카메라로 촬영',
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadFromSource(
                      ImageSourceType.camera,
                      openResult: true,
                    );
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
                ? _buildLivePreview(localizations)
                : DetectionOverlay(
                    scene: scene,
                    selectedObjectId: appState.selectedObjectId,
                    onObjectTap: (object) {
                      appState.selectObject(object.id);
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
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(AppLocalizations? localizations) {
    final previewBytes = _livePreviewBytes;
    final previewWidth = _livePreviewWidth;
    final previewHeight = _livePreviewHeight;

    if (previewBytes == null || previewWidth == null || previewHeight == null) {
      return Center(
        child: Text(localizations?.noSceneLoaded ?? 'No scene loaded yet'),
      );
    }

    return LivePersonPreview(
      imageBytes: previewBytes,
      imageWidth: previewWidth,
      imageHeight: previewHeight,
      personBox: _livePersonBox,
    );
  }

  Future<void> _loadFromSource(
    ImageSourceType sourceType, {
    required bool openResult,
  }) async {
    await _runDetection(
      () => _cameraController.loadImage(sourceType),
      openResult: openResult,
    );
  }

  Future<void> _rerunDetection(AppState notifier) async {
    await _runDetection(() async {
      final scene = notifier.currentScene;
      if (scene == null) return Uint8List(0);
      return scene.imageBytes;
    }, onInvalidBytesMessage: '감지할 이미지가 없어요.');
  }

  Future<void> _runDetection(
    Future<Uint8List> Function() bytesLoader, {
    String? onInvalidBytesMessage,
    bool openResult = false,
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
      final appState = context.read<AppState>();
      await appState.updateDetections(bytes);
      if (openResult) {
        await _saveAndNavigateResult(appState);
      }
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

  void _startLivePreview() {
    _previewSubscription = _cameraController.cameraFrames().listen(
      _handleLiveFrame,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Live preview stream error: $error\n$stackTrace');
      },
    );
  }

  Future<void> _handleLiveFrame(Uint8List bytes) async {
    if (bytes.isEmpty || !mounted) return;

    final now = DateTime.now();
    if (_isInferring || now.difference(_lastInferTime) < _liveInferInterval) {
      return;
    }

    _isInferring = true;
    _lastInferTime = now;

    try {
      final result = await context.read<AppState>().detectLive(bytes);
      if (!mounted) return;

      _livePreviewBytes = result.imageBytes;
      _livePreviewWidth = result.width;
      _livePreviewHeight = result.height;
      _updateLivePersonOverlay(result.objects);
    } catch (err, stackTrace) {
      debugPrint('Live preview inference failed: $err\n$stackTrace');
    } finally {
      _isInferring = false;
    }
  }

  void _updateLivePersonOverlay(List<DetectedObject> objects) {
    final now = DateTime.now();
    final List<DetectedObject> candidates = objects.where((object) {
      final confidence = object.confidence ?? 0;
      return object.label.toLowerCase() == 'person' && confidence >= _livePersonMinConf;
    }).toList();

    if (candidates.isNotEmpty) {
      candidates.sort(
        (a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0),
      );
      final best = candidates.first;
      if (!mounted) return;
      setState(() {
        _livePersonBox = best.bbox;
        _livePersonLastSeenAt = now;
      });
      return;
    }

    final lastSeen = _livePersonLastSeenAt;
    if (lastSeen != null && now.difference(lastSeen) <= _holdDuration) {
      return;
    }

    if (!mounted) return;
    if (_livePersonBox != null || _livePersonLastSeenAt != null) {
      setState(() {
        _livePersonBox = null;
        _livePersonLastSeenAt = null;
      });
    }
  }

  Future<void> _saveAndNavigateResult(AppState appState) async {
    final scene = appState.currentScene;
    if (scene == null) return;

    final now = DateTime.now().toLocal();
    final timestampText = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final filenameTimestamp = DateFormat('yyyyMMdd_HHmmss').format(now);

    final originalStampedBytes = await drawTimestampWatermark(
      originalBytes: scene.imageBytes,
      timestampText: timestampText,
    );
    final detectionStampedBytes = await drawDetectionsOverlay(
      originalBytes: scene.imageBytes,
      timestampText: timestampText,
      detections: scene.objects,
    );

    final directory = Directory('${Directory.systemTemp.path}/show_room_captures');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final originalFile = File(
      '${directory.path}/original_$filenameTimestamp.png',
    );
    final detectionFile = File(
      '${directory.path}/detect_$filenameTimestamp.png',
    );

    await originalFile.writeAsBytes(originalStampedBytes, flush: true);
    await detectionFile.writeAsBytes(detectionStampedBytes, flush: true);

    final summary = _buildSummary(scene.objects);
    final capture = DetectionCapture(
      timestamp: timestampText,
      originalImagePath: originalFile.path,
      detectionImagePath: detectionFile.path,
      summary: summary,
    );
    appState.addCapture(capture);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetectionResultScreen(
          timestamp: timestampText,
          originalImagePath: originalFile.path,
          detectionImagePath: detectionFile.path,
          summary: summary,
        ),
      ),
    );
  }

  String _buildSummary(List<DetectedObject> objects) {
    if (objects.isEmpty) return 'No objects detected';
    final counts = <String, int>{};
    final localizer = LabelLocalizer();
    for (final object in objects) {
      final label = localizer.localize(object.label, context);
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => '${entry.key}:${entry.value}').join(' ');
  }

  void _showObjectSheet(
    BuildContext context,
    DetectedObject object,
    String localizedLabel,
  ) {
    final appState = context.read<AppState>();
    appState.selectObject(object.id);

    final localizations = AppLocalizations.of(context);
    final positionX = object.bbox.left.toStringAsFixed(1);
    final positionY = object.bbox.top.toStringAsFixed(1);
    final sizeWidth = object.bbox.width.toStringAsFixed(1);
    final sizeHeight = object.bbox.height.toStringAsFixed(1);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizedLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  localizations?.objectIdLabel(object.id) ?? 'ID: ${object.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  localizations?.objectBoundingBoxTitle ?? 'Bounding box',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  localizations?.objectBoundingBoxPosition(positionX, positionY) ??
                      'Position: ($positionX, $positionY)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  localizations?.objectBoundingBoxSize(sizeWidth, sizeHeight) ??
                      'Size: $sizeWidth × $sizeHeight',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  localizations?.objectDescription(localizedLabel) ??
                      'Detected as $localizedLabel. Explore or share more details.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  localizations?.objectActionsTitle ?? 'Next actions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.search),
                      onPressed: () => _openSearch(localizedLabel, object),
                      label: Text(
                        localizations?.objectSearchAction ?? 'Search on the web',
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () =>
                          _copyObjectSummary(localizedLabel, object, appState),
                      label: Text(
                        localizations?.objectCopyAction ?? 'Copy object summary',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      final objects = appState.currentScene?.objects ?? [];
      final stillExists = objects.any((candidate) => candidate.id == object.id);
      if (stillExists) {
        appState.selectObject(object.id);
      }
    });
  }

  Future<void> _openSearch(String query, DetectedObject object) async {
    final url = Uri.https('www.google.com', '/search', {'q': query});
    final localizations = AppLocalizations.of(context);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showError(localizations?.objectSearchError ?? "Couldn't open search link");
      }
    } catch (_) {
      _showError(localizations?.objectSearchError ?? "Couldn't open search link");
    }

    final appState = context.read<AppState>();
    final stillExists = appState.currentScene?.objects.any((candidate) => candidate.id == object.id) ??
        false;
    if (stillExists) {
      appState.selectObject(object.id);
    }
  }

  Future<void> _copyObjectSummary(
    String localizedLabel,
    DetectedObject object,
    AppState appState,
  ) async {
    final localizations = AppLocalizations.of(context);
    final positionX = object.bbox.left.toStringAsFixed(1);
    final positionY = object.bbox.top.toStringAsFixed(1);
    final sizeWidth = object.bbox.width.toStringAsFixed(1);
    final sizeHeight = object.bbox.height.toStringAsFixed(1);

    final summary = StringBuffer()
      ..writeln(localizedLabel)
      ..writeln(localizations?.objectIdLabel(object.id) ?? 'ID: ${object.id}')
      ..writeln(localizations?.objectBoundingBoxPosition(positionX, positionY) ??
          'Position: ($positionX, $positionY)')
      ..write(localizations?.objectBoundingBoxSize(sizeWidth, sizeHeight) ??
          'Size: $sizeWidth × $sizeHeight');

    await Clipboard.setData(ClipboardData(text: summary.toString()));
    if (mounted) {
      _showSnack(localizations?.objectCopySuccess ?? 'Copied object info to the clipboard');
    }

    final stillExists = appState.currentScene?.objects.any((candidate) => candidate.id == object.id) ??
        false;
    if (stillExists) {
      appState.selectObject(object.id);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
