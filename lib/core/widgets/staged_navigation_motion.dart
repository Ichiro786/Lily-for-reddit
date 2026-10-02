import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion_tokens.dart';

/// Keeps the body's bottom inset stable while chrome exits in stages.
class StagedNavigationMotion extends StatefulWidget {
  const StagedNavigationMotion({
    super.key,
    required this.visible,
    required this.builder,
  });

  final bool visible;
  final Widget Function(BuildContext, Animation<double>, bool) builder;

  @override
  State<StagedNavigationMotion> createState() => _StagedNavigationMotionState();
}

class _StagedNavigationMotionState extends State<StagedNavigationMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 460),
    value: widget.visible ? 0 : 1,
  )..addListener(_labelsChanged);
  late final Animation<double> _icons = _exit.drive(
    Tween(begin: 1.0, end: 0.0).chain(
      CurveTween(curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic)),
    ),
  );
  bool _labels = true;

  void _labelsChanged() {
    final next = widget.visible && _exit.value < 0.3;
    if (next != _labels) setState(() => _labels = next);
  }

  void _sync() {
    if (MotionTokens.reduced(context)) {
      _exit.value = widget.visible ? 0 : 1;
    } else if (widget.visible) {
      _exit.reverse();
    } else {
      _exit.forward();
    }
    _labelsChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant StagedNavigationMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _sync();
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelsHeight = MediaQuery.textScalerOf(context).scale(12) * 4 / 3;
    final extent =
        math.max(64.0, 48 + labelsHeight) +
        math.max(12.0, MediaQuery.paddingOf(context).bottom);
    return SizedBox(
      height: extent,
      child: AnimatedBuilder(
        animation: _exit,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            child: widget.builder(context, _icons, _labels),
          ),
        ),
        builder: (context, child) {
          final hidden = _exit.value >= 0.999;
          final slide = const Interval(
            0.4,
            1,
            curve: Curves.easeInOutCubic,
          ).transform(_exit.value);
          return ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: TickerMode(
                enabled: !hidden,
                child: Transform.translate(
                  offset: Offset(0, (extent + 24) * slide),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
