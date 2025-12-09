import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'detection_repository.dart';
import 'l10n/app_localizations.dart';
import 'landing_page.dart';
import 'scene_state.dart';
import 'yolo_service.dart';

// Navigation to SceneBootstrapper is handled from LandingPage; keep the
// entrypoint focused on the dependencies it directly uses.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final DetectionRepository repository = useMockDetection
      ? MockDetectionRepository()
      : YoloDetectionRepository(YoloService.instance);

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
      home: const LandingPage(),
    );
  }
}

