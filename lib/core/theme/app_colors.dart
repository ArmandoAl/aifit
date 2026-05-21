import 'package:flutter/material.dart';

/// Carmine Minimalist — tokens from DESIGN.md
class AppColors {
  AppColors._();

  // —— Brand ——
  static const Color primary = Color(0xFFBB0026);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE90032);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color inversePrimary = Color(0xFFFFB3B1);

  // —— Neutrals & surfaces ——
  static const Color background = Color(0xFFF9F9F9);
  static const Color onBackground = Color(0xFF1A1C1C);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF5F3E3D);
  static const Color surfaceDim = Color(0xFFDADADA);
  static const Color surfaceBright = Color(0xFFF9F9F9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F3);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E2);
  static const Color surfaceVariant = Color(0xFFE2E2E2);

  // —— Secondary / tertiary (muted editorial) ——
  static const Color secondary = Color(0xFF5E5E5E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE2E2E2);
  static const Color onSecondaryContainer = Color(0xFF646464);
  static const Color tertiary = Color(0xFF5C5C5C);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // —— Outline & borders ——
  static const Color outline = Color(0xFF946E6C);
  static const Color outlineVariant = Color(0xFFE9BCBA);
  /// Card/list dividers (#EDEDED in design spec)
  static const Color border = Color(0xFFEDEDED);

  // —— Inverse (dark surfaces) ——
  static const Color inverseSurface = Color(0xFF2F3131);
  static const Color onInverseSurface = Color(0xFFF1F1F1);

  // —— Semantic ——
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF2E7D4F);

  // —— Legacy aliases (existing screens) ——
  static const Color primaryVariant = primaryContainer;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = secondary;
  static const Color textTertiary = tertiary;

  /// Material 3 color scheme for [ThemeData].
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: inverseSurface,
        onInverseSurface: onInverseSurface,
        inversePrimary: inversePrimary,
        surfaceContainerHighest: surfaceContainerHighest,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainer: surfaceContainer,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainerLowest: surfaceContainerLowest,
      );
}
