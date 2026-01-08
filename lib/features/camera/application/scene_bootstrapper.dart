import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../camera/infrastructure/image_source_provider.dart';
import '../presentation/camera_screen.dart';

/// Initializes the detection stack and then shows the camera screen.
class SceneBootstrapper extends StatefulWidget {
  const SceneBootstrapper({
    super.key,
    this.imageSourceProvider,
  });

  final ImageSourceProvider? imageSourceProvider;

  @override
  State<SceneBootstrapper> createState() => _SceneBootstrapperState();
}

class _SceneBootstrapperState extends State<SceneBootstrapper> {
  late final ImageSourceProvider _imageSourceProvider;

  @override
  void initState() {
    super.initState();
    _imageSourceProvider = widget.imageSourceProvider ?? DefaultImageSourceProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    await _ensureInterpreterReady();
  }

  Future<void> _ensureInterpreterReady() async {
    await context.read<AppState>().ensureDetectionReady();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.detectionReady) {
      return CameraScreen(
        imageSourceProvider: _imageSourceProvider,
      );
    }

    final errorMessage = appState.detectionInitError;
    final isInitializing =
        appState.detectionInitializing || (!appState.detectionReady && errorMessage == null);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isInitializing ? '초기화 중' : '탐지 초기화 실패',
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInitializing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('모델을 불러오는 중입니다...'),
            ] else ...[
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('탐지 초기화 실패'),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => unawaited(_bootstrap()),
                    child: const Text('재시도'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('뒤로가기'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
