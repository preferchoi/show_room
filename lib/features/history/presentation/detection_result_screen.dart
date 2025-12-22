import 'dart:io';

import 'package:flutter/material.dart';

class DetectionResultScreen extends StatefulWidget {
  const DetectionResultScreen({
    super.key,
    required this.timestamp,
    required this.originalImagePath,
    required this.detectionImagePath,
    required this.summary,
  });

  final String timestamp;
  final String originalImagePath;
  final String detectionImagePath;
  final String summary;

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

enum _ResultView { original, detection }

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  _ResultView _selectedView = _ResultView.original;

  @override
  Widget build(BuildContext context) {
    final imagePath = _selectedView == _ResultView.original
        ? widget.originalImagePath
        : widget.detectionImagePath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<_ResultView>(
                segments: const [
                  ButtonSegment(
                    value: _ResultView.original,
                    label: Text('Original'),
                  ),
                  ButtonSegment(
                    value: _ResultView.detection,
                    label: Text('Detection'),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedView = selection.first;
                  });
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.timestamp,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
