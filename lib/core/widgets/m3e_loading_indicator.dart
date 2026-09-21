import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes the 12-lobed Material 3 Expressive morphing flower path.
///
/// At [progress] = 0.0, the path evaluates to a mathematically exact circle
/// with cubic Bézier fillets.
/// At [progress] = 1.0, the path evaluates to a smooth 12-lobed flower with
/// rounded crests and filleted valleys.
Path computeM3EFlowerPath({
  required Size size,
  required double progress,
  double rotation = 0.0,
  double scale = 1.0,
}) {
  final center = size.center(Offset.zero);
  final maxRadius = math.min(size.width, size.height) / 2;
  if (maxRadius <= 0) return Path();

  final t = progress.clamp(0.0, 1.0);
  final morph = Curves.easeOutCubic.transform(t);

  // When t = 0, crest and valley radii equal baseRadius.
  // The flower expands slightly as it blooms.
  final baseRadius = maxRadius * (0.65 + 0.25 * morph) * scale;

  // Radial amplitude for the 12 lobes:
  // At t = 0: amplitude is 0 (exact circle).
  // At t = 1: amplitude creates 12 distinct, organic petals.
  final deltaCrest = 0.18 * morph;
  final deltaValley = 0.10 * morph;

  final rCrest = baseRadius * (1.0 + deltaCrest);
  final rValley = baseRadius * (1.0 - deltaValley);

  const lobes = 12;
  const numPoints = lobes * 2; // 24 key points: alternating crests and valleys
  final stepAngle = (math.pi * 2) / numPoints; // 15 degrees = pi / 12

  // Cubic Bezier control point tangent distance factor:
  // For circle arc of angle stepAngle: kappa = (4/3) * tan(stepAngle / 4)
  final kappa = (4.0 / 3.0) * math.tan(stepAngle / 4.0);

  final path = Path();

  final p0Radius = rCrest;
  final p0Angle = rotation;
  final startX = center.dx + p0Radius * math.cos(p0Angle);
  final startY = center.dy + p0Radius * math.sin(p0Angle);
  path.moveTo(startX, startY);

  for (var i = 0; i < numPoints; i++) {
    final nextIndex = (i + 1) % numPoints;

    final currentAngle = i * stepAngle + rotation;
    final nextAngle = (i + 1) * stepAngle + rotation;

    final currentRadius = (i % 2 == 0) ? rCrest : rValley;
    final nextRadius = (nextIndex % 2 == 0) ? rCrest : rValley;

    final pCurrX = center.dx + currentRadius * math.cos(currentAngle);
    final pCurrY = center.dy + currentRadius * math.sin(currentAngle);

    final pNextX = center.dx + nextRadius * math.cos(nextAngle);
    final pNextY = center.dy + nextRadius * math.sin(nextAngle);

    // Tangent vectors perpendicular to radius:
    // Outward tangent: (-sin(a), cos(a))
    final dCurr = currentRadius * kappa * (1.0 + 0.15 * morph);
    final dNext = nextRadius * kappa * (1.0 + 0.15 * morph);

    final cp1X = pCurrX - dCurr * math.sin(currentAngle);
    final cp1Y = pCurrY + dCurr * math.cos(currentAngle);

    final cp2X = pNextX + dNext * math.sin(nextAngle);
    final cp2Y = pNextY - dNext * math.cos(nextAngle);

    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, pNextX, pNextY);
  }

  path.close();
  return path;
}

/// Custom painter for the 12-lobed M3 Expressive morphing flower.
class M3EMorphingFlowerPainter extends CustomPainter {
  const M3EMorphingFlowerPainter({
    required this.color,
    required this.progress,
    required this.rotation,
    this.scale = 1.0,
    this.strokeWidth,
  });

  final Color color;
  final double progress;
  final double rotation;
  final double scale;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final path = computeM3EFlowerPath(
      size: size,
      progress: progress,
      rotation: rotation,
      scale: scale,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);

    // Subtle center accent dot when bloomed
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;
    final dotRadius = maxRadius * 0.16 * scale;
    if (dotRadius > 1.0 && progress > 0.25) {
      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28 * progress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(center, dotRadius, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant M3EMorphingFlowerPainter oldDelegate) {
    return color != oldDelegate.color ||
        progress != oldDelegate.progress ||
        rotation != oldDelegate.rotation ||
        scale != oldDelegate.scale ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Material 3 Expressive shape-morphing loading indicator.
///
/// When [progress] is supplied (0.0 to 1.0), renders in pull-driven determinate
/// mode, morphing from a circle to a 12-lobed flower.
/// When [progress] is null, renders in indeterminate active mode with smooth
/// rotation and breathing scale oscillation.
class M3ELoadingIndicator extends StatefulWidget {
  const M3ELoadingIndicator({
    super.key,
    this.size = 32,
    this.strokeWidth = 3.5,
    this.semanticLabel,
    this.color,
    this.progress,
  });

  const M3ELoadingIndicator.small({
    super.key,
    this.semanticLabel,
    this.color,
    this.progress,
  })  : size = 18,
        strokeWidth = 2.5;

  const M3ELoadingIndicator.medium({
    super.key,
    this.semanticLabel,
    this.color,
    this.progress,
  })  : size = 32,
        strokeWidth = 3.5;

  const M3ELoadingIndicator.large({
    super.key,
    this.semanticLabel,
    this.color,
    this.progress,
  })  : size = 48,
        strokeWidth = 4.5;

  final double size;
  final double strokeWidth;
  final String? semanticLabel;
  final Color? color;
  final double? progress;

  @override
  State<M3ELoadingIndicator> createState() => _M3ELoadingIndicatorState();
}

class _M3ELoadingIndicatorState extends State<M3ELoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.progress == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant M3ELoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != null) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    Widget indicator;
    if (widget.progress != null) {
      final t = widget.progress!.clamp(0.0, 1.0);
      final rotation = t * (math.pi / 2);
      indicator = CustomPaint(
        painter: M3EMorphingFlowerPainter(
          color: effectiveColor,
          progress: t,
          rotation: rotation,
          scale: 1.0,
          strokeWidth: widget.strokeWidth,
        ),
      );
    } else {
      indicator = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rotation = _controller.value * math.pi * 2;
          final pulse = 1.0 + math.sin(rotation) * 0.06;
          return CustomPaint(
            painter: M3EMorphingFlowerPainter(
              color: effectiveColor,
              progress: 1.0,
              rotation: rotation,
              scale: pulse,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? 'Loading...',
      liveRegion: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: indicator,
      ),
    );
  }
}
