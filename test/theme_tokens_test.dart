import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luli_for_reddit/core/theme/app_theme.dart';
import 'package:luli_for_reddit/core/theme/color_schemes.dart';
import 'package:luli_for_reddit/core/theme/shape_tokens.dart';
import 'package:luli_for_reddit/core/theme/typography.dart';

void main() {
  test('M3E dark, AMOLED, and light surface roles are distinct and valid', () {
    final schemes = <ColorScheme>[
      M3EColorSchemes.dark,
      M3EColorSchemes.amoled,
      M3EColorSchemes.light,
    ];

    for (final scheme in schemes) {
      final surfaces = [
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      expect(surfaces.every((color) => color.a > 0), isTrue);
      expect(surfaces.toSet(), hasLength(5));
    }

    expect(M3EColorSchemes.amoled.surface, Colors.black);
    expect(M3EColorSchemes.dark.surface, isNot(Colors.black));
  });

  test('shape tokens match the M3E expressive radius scale', () {
    expect(ShapeTokens.full.topLeft.x, 999);
    expect(ShapeTokens.extraLarge.topLeft.x, 28);
    expect(ShapeTokens.large.topLeft.x, 24);
    expect(ShapeTokens.medium.topLeft.x, 20);
    expect(ShapeTokens.small.topLeft.x, 16);
    expect(ShapeTokens.extraSmall.topLeft.x, 12);
    expect(ShapeTokens.none, BorderRadius.zero);
    expect(ShapeTokens.largeShape.borderRadius, ShapeTokens.large);
  });

  test('typography tokens match the calibrated expressive scale', () {
    expect(M3ETypography.headlineLarge.fontSize, 32);
    expect(M3ETypography.headlineLarge.height, closeTo(40 / 32, 0.000001));
    expect(M3ETypography.headlineLarge.fontWeight, FontWeight.w700);
    expect(M3ETypography.headlineMedium.fontSize, 28);
    expect(M3ETypography.titleLarge.fontSize, 22);
    expect(M3ETypography.titleMedium.fontSize, 16);
    expect(M3ETypography.bodyLarge.letterSpacing, 0.5);
    expect(M3ETypography.bodyMedium.letterSpacing, 0.25);
    expect(M3ETypography.bodySmall.letterSpacing, 0.4);
    expect(M3ETypography.labelSmall.fontSize, 11);
    expect(M3ETypography.labelSmall.fontWeight, FontWeight.w500);
  });

  test('AppTheme factories build complete M3E ThemeData instances', () {
    final light = AppTheme.light(null);
    final dark = AppTheme.dark(null);
    final amoled = AppTheme.dark(null, amoled: true);

    for (final theme in [light, dark, amoled]) {
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.surfaceContainer, isNotNull);
      expect(theme.textTheme.titleLarge, isNotNull);
      expect(theme.cardTheme.shape, ShapeTokens.largeShape);
      expect(theme.dialogTheme.shape, ShapeTokens.largeShape);
    }

    expect(amoled.colorScheme.surface, Colors.black);
    expect(dark.bottomSheetTheme.backgroundColor,
        dark.colorScheme.surfaceContainerHigh);
    expect(light.chipTheme.shape, ShapeTokens.fullShape);
  });
}
