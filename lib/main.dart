import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'scene_state.dart';
import 'scene_view_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SceneState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scene Overlay Demo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const SceneBootstrapper(),
    );
  }
}

/// Loads a mock scene on startup and shows the scene page.
class SceneBootstrapper extends StatefulWidget {
  const SceneBootstrapper({super.key});

  @override
  State<SceneBootstrapper> createState() => _SceneBootstrapperState();
}

class _SceneBootstrapperState extends State<SceneBootstrapper> {
  @override
  void initState() {
    super.initState();
    _loadMockScene();
  }

  void _loadMockScene() {
    // Mock image: 600x400 solid color PNG encoded in base64 so it works offline.
    const imageBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAlgAAAGQCAIAAAD9V4nPAAAF/ElEQVR4nO3VMQ0AMAzAsPJHNhDjssHoEUsGkC9z7gOArFkvAIBFRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkGaEAKQZIQBpRghAmhECkPYBezx9WRmhllgAAAAASUVORK5CYII=';

    final sceneBytes = base64Decode(imageBase64);
    final mockScene = SceneDetectionResult(
      imageBytes: sceneBytes,
      width: 600,
      height: 400,
      objects: const [
        DetectedObject(
          id: '1',
          label: 'Desk',
          bbox: Rect.fromLTWH(80, 180, 200, 140),
        ),
        DetectedObject(
          id: '2',
          label: 'Chair',
          bbox: Rect.fromLTWH(320, 200, 120, 140),
        ),
        DetectedObject(
          id: '3',
          label: 'Plant',
          bbox: Rect.fromLTWH(480, 100, 70, 120),
        ),
      ],
    );

    // Defer setting the scene to after the first frame so the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SceneState>().setScene(mockScene);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SceneViewPage();
  }
}
