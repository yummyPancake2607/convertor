import 'package:flutter/material.dart';

/// Type scale tuned for desktop density.
///
/// No web fonts are used: the application must work with zero network access,
/// so we rely on the platform/Flutter bundled families only.
abstract final class AppTypography {
  static const String? fontFamily = null; // platform default

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      // Display / page titles
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 21,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      // Section headers / card titles
      titleMedium: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      // Labels / buttons / metadata
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: secondary,
      ),
    );
  }

  /// Monospace style for paths, sizes and technical values.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Courier New', 'DejaVu Sans Mono'],
    fontSize: 12,
    height: 1.4,
  );
}
