import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../history/presentation/history_screen.dart';
import '../application/scene_bootstrapper.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const Color backgroundColor = Color(0xFFFF00FF);
  static const Color logoColor = Color(0xFFFF9BC2);

  String get _logoSvg {
    return '<svg width="120" height="120" xmlns="http://www.w3.org/2000/svg">'
        '<rect x="10" y="10" width="100" height="100" rx="16" '
        'fill="#ff9bc2" />'
        '</svg>';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.string(_logoSvg),
                      const SizedBox(height: 16),
                      Text(
                        'Show Room',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SceneBootstrapper(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          textStyle: Theme.of(context).textTheme.titleMedium,
                        ),
                        child: const Text('장면 감지 시작'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          foregroundColor: Colors.white,
                          textStyle: Theme.of(context).textTheme.titleMedium,
                        ),
                        child: const Text('검출 기록 보기'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withValues(alpha: 0.6),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        child: const Text('준비중'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
