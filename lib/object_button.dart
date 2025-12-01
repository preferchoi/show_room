import 'package:flutter/material.dart';

import 'models.dart';

/// A tap target that outlines a detected object region.
class ObjectButton extends StatelessWidget {
  const ObjectButton({
    super.key,
    required this.object,
    required this.isSelected,
    required this.onTap,
  });

  final DetectedObject object;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    final borderWidth = isSelected ? 3.0 : 1.0;
    final borderRadius = BorderRadius.circular(6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
