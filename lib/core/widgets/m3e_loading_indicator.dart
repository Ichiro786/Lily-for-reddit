import 'package:flutter/material.dart';

class M3ELoadingIndicator extends StatelessWidget {
  const M3ELoadingIndicator({
    super.key,
    this.size = 32,
    this.strokeWidth = 3.5,
    this.semanticLabel,
  });

  const M3ELoadingIndicator.small({
    super.key,
    this.semanticLabel,
  })  : size = 18,
        strokeWidth = 2.5;

  const M3ELoadingIndicator.medium({
    super.key,
    this.semanticLabel,
  })  : size = 32,
        strokeWidth = 3.5;

  const M3ELoadingIndicator.large({
    super.key,
    this.semanticLabel,
  })  : size = 48,
        strokeWidth = 4.5;

  final double size;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? 'Loading...',
      liveRegion: true,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          color: colorScheme.primary,
          backgroundColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
