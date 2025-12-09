import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({
    super.key,
    required this.logoColor,
  });

  final Color logoColor;

  @override
  Widget build(BuildContext context) {
    final logoSvg = _logoSvg;
    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.6 / 0.7),
      body: Center(
        child: Text(
          logoSvg,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: logoColor.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }

  String get _logoSvg {
    final red = (logoColor.red * 255).round().clamp(0, 255).toInt();
    final green = (logoColor.green * 255).round().clamp(0, 255).toInt();
    final blue = (logoColor.blue * 255).round().clamp(0, 255).toInt();
    final fillColor = '#'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
    return '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="10" fill="$fillColor" />
</svg>
''';
  }
}