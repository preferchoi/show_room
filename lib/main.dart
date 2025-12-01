import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'detection_repository.dart';
import 'image_source_provider.dart';
import 'l10n/app_localizations.dart';
import 'scene_state.dart';
import 'scene_view_page.dart';
import 'yolo_seg_service.dart';

// Toggle between the fully offline mock backend and the YOLO-backed backend.
// Keep this true while YoloService still contains TODOs (normalization,
// parsing, labels, etc.) so the UI can run safely end-to-end.
const bool useMockDetection = true;
const ImageSourceType defaultImageSource = ImageSourceType.sample;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final yoloService = YoloSegService.instance;
  if (!useMockDetection) {
    // Only initialize the interpreter when the YOLO-backed flow is enabled.
    await yoloService.init();
  }

  final DetectionRepository repository = useMockDetection
      ? MockDetectionRepository()
      : YoloSegDetectionRepository(yoloService);

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
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Scene Overlay Demo',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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

  @override
  void initState() {
    super.initState();
    _imageSourceProvider = widget.imageSourceProvider ?? DefaultImageSourceProvider();
    // Defer the load to the first frame so the provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialScene());
    });
  }

  Future<void> _loadInitialScene() async {
    try {
      final Uint8List bytes =
          await _imageSourceProvider.loadImage(widget.defaultSourceType);
      await context.read<SceneState>().loadScene(bytes);
    } on ImageSourceException catch (err) {
      _showError(err.message);
    } catch (err) {
      debugPrint('Failed to load initial scene: $err');
      _showError('이미지를 불러오지 못했어요. 다시 시도해주세요.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SceneViewPage();
  }
}
