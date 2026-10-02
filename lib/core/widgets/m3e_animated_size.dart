import 'package:flutter/material.dart';
import '../theme/motion_tokens.dart';

/// Skip layout animation entirely for reduced motion. AnimatedSize with a zero
/// duration can notify during layout; an unchanged wrapper avoids that path.
class M3EAnimatedSize extends StatelessWidget {
  const M3EAnimatedSize({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) => MotionTokens.reduced(context)
      ? child
      : AnimatedSize(
          duration: MotionTokens.content(context),
          curve: MotionTokens.emphasized,
          alignment: alignment,
          child: child,
        );
}
