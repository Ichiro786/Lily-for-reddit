import 'package:flutter/material.dart';

/// Shared content motion; honors Android remove animations and iOS reduce motion.
abstract final class MotionTokens {
  static Duration content(BuildContext context) =>
      reduced(context) ? Duration.zero : const Duration(milliseconds: 300);

  static Duration feedback(BuildContext context) =>
      reduced(context) ? Duration.zero : const Duration(milliseconds: 180);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}
