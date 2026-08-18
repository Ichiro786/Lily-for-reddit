import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M3EScallopedSpinner extends StatefulWidget {
  const M3EScallopedSpinner({
    super.key,
    this.progress = 1,
    this.refreshing = false,
    this.size = 42,
    this.semanticLabel = 'Refreshing',
  });

  final double progress;
  final bool refreshing;
  final double size;
  final String semanticLabel;

  @override
  State<M3EScallopedSpinner> createState() => _M3EScallopedSpinnerState();
}

class _M3EScallopedSpinnerState extends State<M3EScallopedSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant M3EScallopedSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.refreshing) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else if (_rotation.isAnimating) {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final progress = widget.progress.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _rotation,
          builder: (_, __) {
            final eased = Curves.easeInOutCubic.transform(_rotation.value);
            final breathing = widget.refreshing
                ? 0.92 + (0.16 * (0.5 + 0.5 *
                    math.sin(_rotation.value * math.pi * 2)))
                : 1.0;
            return CustomPaint(
              painter: _M3EScallopedPainter(
                color: color,
                progress: progress,
                rotation: widget.refreshing ? eased * math.pi * 2 : 0,
                scale: breathing,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _M3EScallopedPainter extends CustomPainter {
  const _M3EScallopedPainter({
    required this.color,
    required this.progress,
    required this.rotation,
    required this.scale,
  });

  final Color color;
  final double progress;
  final double rotation;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;
    final morph = Curves.easeOutCubic.transform(progress);
    final radius = (maxRadius * morph * scale).clamp(0.0, maxRadius).toDouble();
    if (radius <= 0.1) return;

    const lobes = 10;
    const samplesPerLobe = 4;
    final sampleCount = lobes * samplesPerLobe;
    final points = <Offset>[];
    final amplitude = 0.17 * morph;

    for (var i = 0; i < sampleCount; i++) {
      final theta = (i / sampleCount) * math.pi * 2 + rotation;
      final harmonic = math.sin(theta * lobes);
      final pointRadius = radius * (0.82 + amplitude * harmonic);
      points.add(
        center + Offset(
          math.cos(theta) * pointRadius,
          math.sin(theta) * pointRadius,
        ),
      );
    }

    final path = Path();
    for (var i = 0; i < sampleCount; i++) {
      final p0 = points[(i - 1 + sampleCount) % sampleCount];
      final p1 = points[i];
      final p2 = points[(i + 1) % sampleCount];
      final p3 = points[(i + 2) % sampleCount];
      final control1 = p1 + (p2 - p0) / 6;
      final control2 = p2 - (p3 - p1) / 6;
      if (i == 0) path.moveTo(p1.dx, p1.dy);
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p2.dx,
        p2.dy,
      );
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _M3EScallopedPainter oldDelegate) {
    return color != oldDelegate.color ||
        progress != oldDelegate.progress ||
        rotation != oldDelegate.rotation ||
        scale != oldDelegate.scale;
  }
}

class M3ERefreshIndicator extends StatefulWidget {
  const M3ERefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.triggerExtent = 96,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double triggerExtent;

  @override
  M3ERefreshIndicatorState createState() => M3ERefreshIndicatorState();
}

class M3ERefreshIndicatorState extends State<M3ERefreshIndicator>
    with SingleTickerProviderStateMixin {
  double _pullExtent = 0;
  bool _refreshing = false;
  bool _thresholdReached = false;
  late final AnimationController _dismiss;

  double get _progress =>
      (_pullExtent / widget.triggerExtent).clamp(0.0, 1.0).toDouble();

  @override
  void initState() {
    super.initState();
    _dismiss = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _dismiss.dispose();
    super.dispose();
  }

  Future<void> show() async {
    if (_refreshing) return;
    _dismiss.forward();
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerExtent;
      _thresholdReached = true;
    });
    await _refresh();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || _refreshing) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _setPullExtent(_pullExtent - notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      _setPullExtent(
          notification.metrics.minScrollExtent - notification.metrics.pixels);
    } else if (notification is ScrollEndNotification && _pullExtent > 0) {
      if (_progress >= 1) {
        _startRefresh();
      } else {
        _resetPull();
      }
    }
    return false;
  }

  void _setPullExtent(double extent) {
    final next = extent.clamp(0.0, widget.triggerExtent * 1.35).toDouble();
    if (next > 0 && !_dismiss.isAnimating && _dismiss.value < 1) {
      _dismiss.forward();
    }
    if (next >= widget.triggerExtent && !_thresholdReached) {
      _thresholdReached = true;
      HapticFeedback.mediumImpact();
    } else if (next < widget.triggerExtent) {
      _thresholdReached = false;
    }
    if (mounted && next != _pullExtent) {
      setState(() => _pullExtent = next);
    }
  }

  void _startRefresh() {
    if (_refreshing) return;
    _dismiss.forward();
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerExtent;
    });
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullExtent = 0;
          _thresholdReached = false;
        });
        _dismiss.reverse();
      }
    }
  }

  void _resetPull() {
    if (!mounted) return;
    setState(() {
      _pullExtent = 0;
      _thresholdReached = false;
    });
    _dismiss.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _dismiss,
      builder: (context, child) {
        final visible = _refreshing || _pullExtent > 0 || _dismiss.value > 0;
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              child!,
              if (visible)
                Positioned(
                  top: 8 + (_pullExtent * 0.22),
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: _dismiss.value,
                        child: Transform.scale(
                          scale: 0.72 + (_dismiss.value * 0.28),
                          child: Material(
                            color: colorScheme.surfaceContainerHigh,
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.22),
                            shape: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: M3EScallopedSpinner(
                                progress: _refreshing
                                    ? 1
                                    : (_pullExtent > 0
                                        ? _progress
                                        : _dismiss.value),
                                refreshing: _refreshing,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
