import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../camera/presentation/landing_page.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().detectionHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('검출 기록'),
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('검출한 물체가 없어요.'),
                  SizedBox(height: 8),
                  Text('카메라에서 탐지를 실행하면 기록이 쌓입니다.'),
                ],
              ),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final object = history[index];
                final bbox = object.bbox;
                final initial =
                    object.label.isNotEmpty ? object.label[0].toUpperCase() : '?';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: LandingPage.logoColor.withValues(alpha: 0.25),
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  title: Text(object.label),
                  subtitle: Text(
                    '(${bbox.left.toStringAsFixed(1)}, ${bbox.top.toStringAsFixed(1)}) · '
                    '${bbox.width.toStringAsFixed(1)}×${bbox.height.toStringAsFixed(1)}',
                  ),
                );
              },
            ),
    );
  }
}
