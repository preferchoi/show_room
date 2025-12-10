import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _modelPathController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _modelPathController = TextEditingController(text: appState.modelPath);
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Confidence threshold',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: appState.confidenceThreshold,
                min: 0,
                max: 1,
                divisions: 20,
                label: appState.confidenceThreshold.toStringAsFixed(2),
                onChanged: (value) => appState.setConfidenceThreshold(value),
              ),
              const SizedBox(height: 16),
              Text(
                'Model path',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextField(
                controller: _modelPathController,
                decoration: const InputDecoration(
                  hintText: 'assets/models/yolo11n.tflite',
                ),
                onChanged: appState.setModelPath,
              ),
            ],
          ),
        );
      },
    );
  }
}
