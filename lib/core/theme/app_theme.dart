import 'package:flutter/material.dart';

import 'color_schemes.dart';
import 'shape_tokens.dart';
import 'typography.dart';

/// Upvote / downvote accent colors, exposed as a theme extension so vote
/// controls can read brightness-correct colors.
@immutable
class VoteColors extends ThemeExtension<VoteColors> {
  const VoteColors({required this.up, required this.down});

  final Color up;
  final Color down;

  @override
  VoteColors copyWith({Color? up, Color? down}) =>
      VoteColors(up: up ?? this.up, down: down ?? this.down);

  @override
  VoteColors lerp(ThemeExtension<VoteColors>? other, double t) {
    if (other is! VoteColors) return this;
    return VoteColors(
      up: Color.lerp(up, other.up, t)!,
      down: Color.lerp(down, other.down, t)!,
    );
  }
}

/// Material 3 Expressive theme factory used by the application.
class AppTheme {
  AppTheme._();

  /// Backwards-compatible default accent used by settings and dynamic schemes.
  static const Color seed = Color(0xFF6750A4);

  /// Backwards-compatible names for the centralized M3E schemes.
  static const ColorScheme bloomLight = M3EColorSchemes.light;
  static const ColorScheme bloomDark = M3EColorSchemes.dark;

  static const _voteLight = VoteColors(
    up: Color(0xFFD93900),
    down: Color(0xFF605BFF),
  );
  static const _voteDark = VoteColors(
    up: Color(0xFFFF7E54),
    down: Color(0xFFBFC0FF),
  );

  static ColorScheme _baseScheme(
      ColorScheme? dynamicScheme, Color seed, Brightness brightness) {
    if (dynamicScheme != null) return dynamicScheme;
    if (seed.toARGB32() == AppTheme.seed.toARGB32()) {
      return brightness == Brightness.light
          ? M3EColorSchemes.light
          : M3EColorSchemes.dark;
    }
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  }

  static ThemeData light(ColorScheme? dynamicScheme,
      {Color seed = AppTheme.seed}) {
    return _build(
      _baseScheme(dynamicScheme, seed, Brightness.light),
      Brightness.light,
    );
  }

  static ThemeData dark(
    ColorScheme? dynamicScheme, {
    Color seed = AppTheme.seed,
    bool amoled = false,
  }) {
    var scheme = _baseScheme(dynamicScheme, seed, Brightness.dark);
    if (amoled) {
      scheme = scheme.copyWith(
        surface: M3EColorSchemes.amoled.surface,
        surfaceDim: M3EColorSchemes.amoled.surfaceDim,
        surfaceContainerLowest: M3EColorSchemes.amoled.surfaceContainerLowest,
        surfaceContainerLow: M3EColorSchemes.amoled.surfaceContainerLow,
        surfaceContainer: M3EColorSchemes.amoled.surfaceContainer,
        surfaceContainerHigh: M3EColorSchemes.amoled.surfaceContainerHigh,
        surfaceContainerHighest: M3EColorSchemes.amoled.surfaceContainerHighest,
      );
    }
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: M3ETypography.textTheme(scheme.onSurface),
      extensions: [brightness == Brightness.light ? _voteLight : _voteDark],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: M3ETypography.titleLarge.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: ShapeTokens.largeShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: ShapeTokens.largeShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: ShapeTokens.fullShape,
          textStyle: M3ETypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: ShapeTokens.fullShape,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: ShapeTokens.fullShape,
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: ShapeTokens.small,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ShapeTokens.small,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ShapeTokens.small,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        shape: ShapeTokens.mediumShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: ShapeTokens.smallShape,
      ),
    );
  }
}
