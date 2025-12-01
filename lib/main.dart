import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'detection_repository.dart';
import 'image_source_provider.dart';
import 'scene_state.dart';
import 'scene_view_page.dart';
import 'yolo_service.dart';

// Toggle between the fully offline mock backend and the YOLO-backed backend.
// Keep this true while YoloService still contains TODOs (normalization,
// parsing, labels, etc.) so the UI can run safely end-to-end.
const bool useMockDetection = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final yoloService = YoloService.instance;
  if (!useMockDetection) {
    // Only initialize the interpreter when the YOLO-backed flow is enabled.
    await yoloService.init();
  }

  final DetectionRepository repository = useMockDetection
      ? MockDetectionRepository()
      : YoloDetectionRepository(yoloService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SceneState(repository),
        ),
      ],
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
        colorScheme:
            ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const SceneBootstrapper(),
    );
  }
}

/// Loads a scene on startup and shows the scene page. The initial load uses the
/// sample image source so the app can launch with no runtime permissions or
/// model files when `useMockDetection` is true.
class SceneBootstrapper extends StatefulWidget {
  const SceneBootstrapper({super.key});

  @override
  State<SceneBootstrapper> createState() => _SceneBootstrapperState();
}

class _SceneBootstrapperState extends State<SceneBootstrapper> {
  final ImageSourceProvider _imageSourceProvider = SampleImageSourceProvider();

  @override
  void initState() {
    super.initState();
    // Defer the load to the first frame so the provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialScene());
    });
  }

  Future<void> _loadInitialScene() async {
    try {
      // Extension point: swap [ImageSourceType.sample] with gallery/camera once
      // those sources are implemented. The detection backend remains untouched.
      final Uint8List bytes = await _imageSourceProvider.loadImage(ImageSourceType.sample);
      await context.read<SceneState>().loadScene(bytes);
    } catch (err) {
      // For now, surface basic errors. This keeps the mock flow resilient even
      // while future camera/gallery implementations are stubbed out.
      debugPrint('Failed to load initial scene: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SceneViewPage();
  }
}
