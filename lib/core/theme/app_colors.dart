import 'package:flutter/material.dart';

/// Maison Atelier — editorial fashion tokens.
/// Warm parchment canvas, espresso ink, burgundy wine, champagne gold.
class AppColors {
  AppColors._();

  // —— Brand ——
  static const Color primary = Color(0xFF5C2433);
  static const Color onPrimary = Color(0xFFFBF8F4);
  static const Color primaryContainer = Color(0xFF7A3344);
  static const Color onPrimaryContainer = Color(0xFFFBF8F4);
  static const Color inversePrimary = Color(0xFFD4A3AE);

  /// Champagne gold — jewelry-level accent for fashion details.
  static const Color gold = Color(0xFFC4A574);
  static const Color onGold = Color(0xFF1A1410);
  static const Color goldSoft = Color(0xFFE8D5B5);

  // —— Neutrals & surfaces ——
  static const Color background = Color(0xFFF3EEE6);
  static const Color onBackground = Color(0xFF1A1410);
  static const Color surface = Color(0xFFFBF8F4);
  static const Color onSurface = Color(0xFF1A1410);
  static const Color onSurfaceVariant = Color(0xFF5E4A46);
  static const Color surfaceDim = Color(0xFFE4D9CC);
  static const Color surfaceBright = Color(0xFFFBF8F4);
  static const Color surfaceContainerLowest = Color(0xFFFFFCF8);
  static const Color surfaceContainerLow = Color(0xFFF6F0E8);
  static const Color surfaceContainer = Color(0xFFEDE4DA);
  static const Color surfaceContainerHigh = Color(0xFFE6D9C8);
  static const Color surfaceContainerHighest = Color(0xFFDDCFBE);
  static const Color surfaceVariant = Color(0xFFE6D9C8);

  // —— Secondary / tertiary (warm taupe) ——
  static const Color secondary = Color(0xFF74685E);
  static const Color onSecondary = Color(0xFFFBF8F4);
  static const Color secondaryContainer = Color(0xFFE8D9C6);
  static const Color onSecondaryContainer = Color(0xFF3D342C);
  static const Color tertiary = Color(0xFF8A7B70);
  static const Color onTertiary = Color(0xFFFBF8F4);

  // —— Outline & borders ——
  static const Color outline = Color(0xFFB9A898);
  static const Color outlineVariant = Color(0xFFD8C9B8);
  static const Color border = Color(0xFFE4D6C6);

  // —— Inverse (dark atelier surfaces) ——
  static const Color inverseSurface = Color(0xFF1A1410);
  static const Color onInverseSurface = Color(0xFFF3EEE6);

  // —— Semantic ——
  static const Color error = Color(0xFF9B2C2C);
  static const Color onError = Color(0xFFFBF8F4);
  static const Color errorContainer = Color(0xFFF5D6D0);
  static const Color onErrorContainer = Color(0xFF5C1212);
  static const Color success = Color(0xFF3F6B4C);

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
