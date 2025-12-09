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
      body: Center(
        child: Text(
          logoSvg,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String get _logoSvg {
    final fillColor =
        '#${logoColor.red.toRadixString(16).padLeft(2, '0')}${logoColor.green.toRadixString(16).padLeft(2, '0')}${logoColor.blue.toRadixString(16).padLeft(2, '0')}';
    return '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="10" fill="$fillColor" />
</svg>
''';
  }
}