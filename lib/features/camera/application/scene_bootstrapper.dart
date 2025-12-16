import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/state/app_state.dart';
import '../../camera/infrastructure/image_source_provider.dart';
import '../../detection/infrastructure/yolo_service.dart';
import '../presentation/camera_screen.dart';

/// Loads a scene on startup and shows the scene page. The initial load uses the
/// sample image source when `useMockDetection` is true so the app can launch
/// with no runtime permissions or model files. Otherwise, the camera is
/// triggered after the model is initialized.
class SceneBootstrapper extends StatefulWidget {
  const SceneBootstrapper({
    super.key,
    this.defaultSourceType = defaultImageSource,
    this.imageSourceProvider,
  });

  final ImageSourceType defaultSourceType;
  final ImageSourceProvider? imageSourceProvider;

  @override
  State<SceneBootstrapper> createState() => _SceneBootstrapperState();
}

class _SceneBootstrapperState extends State<SceneBootstrapper> {
  late final ImageSourceProvider _imageSourceProvider;
  _InitStatus _initStatus = useMockDetection ? _InitStatus.success : _InitStatus.idle;
  String? _initErrorMessage;

  @override
  void initState() {
    super.initState();
    _imageSourceProvider = widget.imageSourceProvider ?? DefaultImageSourceProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    if (!useMockDetection) {
      await _ensureInterpreterReady();
      if (_initStatus != _InitStatus.success) return;
      await _detectFromSource(ImageSourceType.camera);
      return;
    }
    await _loadInitialScene();
  }

  Future<void> _ensureInterpreterReady() async {
    if (_initStatus == _InitStatus.initializing) return;
    setState(() {
      _initStatus = _InitStatus.initializing;
      _initErrorMessage = null;
    });

    try {
      await YoloService.instance.init();
      if (!mounted) return;
      setState(() {
        _initStatus = _InitStatus.success;
      });
    } catch (err, stackTrace) {
      debugPrint('Failed to initialize interpreter: $err\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _initStatus = _InitStatus.error;
        _initErrorMessage = '모델 초기화에 실패했어요. 다시 시도해주세요.';
      });
      _showErrorSnack();
      await _showInitFailureDialog();
    }
  }

  Future<void> _loadInitialScene() async {
    await _detectFromSource(widget.defaultSourceType);
  }

  Future<void> _detectFromSource(ImageSourceType sourceType) async {
    try {
      final Uint8List bytes = await _imageSourceProvider.loadImage(sourceType);
      await context.read<AppState>().updateDetections(bytes);
    } on ImageSourceException catch (err) {
      _showError(err.message);
    } catch (err) {
      debugPrint('Failed to load initial scene from $sourceType: $err');
      _showError('이미지를 불러오지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _showInitFailureDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모델을 불러오지 못했어요'),
          content: Text(_initErrorMessage ?? '잠시 후 다시 시도해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_bootstrap());
              },
              child: const Text('다시 시도'),
            ),
          ],
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

  void _showErrorSnack() {
    if (!mounted || _initErrorMessage == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_initErrorMessage!),
        action: SnackBarAction(
          label: '재시도',
          onPressed: () {
            unawaited(_bootstrap());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useMockDetection || _initStatus == _InitStatus.success) {
      return CameraScreen(
        imageSourceProvider: _imageSourceProvider,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('초기화 중'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_initStatus == _InitStatus.initializing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('모델을 불러오는 중입니다...'),
            ] else ...[
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_initErrorMessage ?? '모델 초기화에 실패했어요.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => unawaited(_bootstrap()),
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _InitStatus {
  idle,
  initializing,
  success,
  error,
}
