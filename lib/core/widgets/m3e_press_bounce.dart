import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion_tokens.dart';

/// Local spring feedback; the child and its tap callback stay immediate.
class M3EPressBounce extends StatefulWidget {
  const M3EPressBounce({super.key, required this.child, this.selected = false});
  final Widget child;
  final bool selected;

  @override
  State<M3EPressBounce> createState() => _M3EPressBounceState();
}

class _M3EPressBounceState extends State<M3EPressBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 24,
  );

  void _release() {
    if (MotionTokens.reduced(context)) {
      _scale.value = 1;
    } else {
      _scale.animateWith(SpringSimulation(_spring, _scale.value, 1, 1.4));
    }
  }

  @override
  void didUpdateWidget(covariant M3EPressBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected &&
        !oldWidget.selected &&
        !MotionTokens.reduced(context)) {
      _scale.value = 0.95;
      _release();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionTokens.reduced(context)) {
      _scale.stop();
      _scale.value = 1;
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (!MotionTokens.reduced(context)) {
        _scale.animateTo(
          0.95,
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOutCubic,
        );
      }
    },
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedBuilder(
      animation: _scale,
      child: widget.child,
      builder: (_, child) =>
          Transform.scale(scale: _scale.value.clamp(0.94, 1.03), child: child),
    ),
  );
}
