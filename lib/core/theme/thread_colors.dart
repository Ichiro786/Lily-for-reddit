import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Rainbow navigational accents harmonized to the device's active palette.
/// Content and surfaces continue to use ColorScheme roles.
@immutable
class ThreadColors extends ThemeExtension<ThreadColors> {
  const ThreadColors(this.rails);
  final List<Color> rails;

  factory ThreadColors.fromScheme(ColorScheme scheme) => ThreadColors([
    for (final hue in [275.0, 215.0, 165.0, 95.0, 45.0, 5.0, 325.0])
      ColorScheme.fromSeed(
        seedColor: HSLColor.fromAHSL(
          1,
          hue,
          0.8,
          0.5,
        ).toColor().harmonizeWith(scheme.primary),
        brightness: scheme.brightness,
      ).primary,
  ]);

  Color atDepth(int depth) => rails[(depth - 1).clamp(0, 999) % rails.length];

  @override
  ThreadColors copyWith({List<Color>? rails}) =>
      ThreadColors(rails ?? this.rails);

  @override
  ThreadColors lerp(ThemeExtension<ThreadColors>? other, double t) {
    if (other is! ThreadColors || other.rails.length != rails.length) {
      return this;
    }
    return ThreadColors([
      for (var i = 0; i < rails.length; i++)
        Color.lerp(rails[i], other.rails[i], t)!,
    ]);
  }
}
