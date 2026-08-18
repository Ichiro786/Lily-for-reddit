import 'package:flutter/material.dart';

abstract final class M3ETypography {
  const M3ETypography._();

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.25,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
  );

  static TextTheme textTheme(Color color) => TextTheme(
        headlineLarge: headlineLarge.copyWith(color: color),
        headlineMedium: headlineMedium.copyWith(color: color),
        titleLarge: titleLarge.copyWith(color: color),
        titleMedium: titleMedium.copyWith(color: color),
        titleSmall: titleSmall.copyWith(color: color),
        bodyLarge: bodyLarge.copyWith(color: color),
        bodyMedium: bodyMedium.copyWith(color: color),
        bodySmall: bodySmall.copyWith(color: color),
        labelLarge: labelLarge.copyWith(color: color),
        labelMedium: labelMedium.copyWith(color: color),
        labelSmall: labelSmall.copyWith(color: color),
      );
}
