import 'package:flutter/material.dart';

/// Semantic colour tokens for the application.
///
/// Exposed as a [ThemeExtension] so widgets never hard-code a light/dark
/// branch: they read `context.palette.<token>` and the correct value for the
/// active theme is supplied by [ThemeData].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.windowBackground,
    required this.sidebarBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.surfaceHover,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.onAccent,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.error,
    required this.errorSubtle,
    required this.info,
    required this.infoSubtle,
    required this.video,
    required this.audio,
    required this.image,
    required this.document,
    required this.neutral,
    required this.shadow,
  });

  // Structure
  final Color windowBackground;
  final Color sidebarBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSunken;
  final Color surfaceHover;
  final Color border;
  final Color borderStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Brand
  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color onAccent;

  // Status
  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color error;
  final Color errorSubtle;
  final Color info;
  final Color infoSubtle;

  // Media categories
  final Color video;
  final Color audio;
  final Color image;
  final Color document;
  final Color neutral;

  final Color shadow;

  static const AppPalette dark = AppPalette(
    windowBackground: Color(0xFF0E1014),
    sidebarBackground: Color(0xFF12151A),
    surface: Color(0xFF171A20),
    surfaceElevated: Color(0xFF1E222A),
    surfaceSunken: Color(0xFF0B0D11),
    surfaceHover: Color(0xFF23282F),
    border: Color(0xFF262B33),
    borderStrong: Color(0xFF343A44),
    textPrimary: Color(0xFFE9EBEF),
    textSecondary: Color(0xFF98A0AC),
    textTertiary: Color(0xFF6A727E),
    accent: Color(0xFF6D7CFF),
    accentHover: Color(0xFF8290FF),
    accentSubtle: Color(0x266D7CFF),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF3DD68C),
    successSubtle: Color(0x263DD68C),
    warning: Color(0xFFF5A524),
    warningSubtle: Color(0x26F5A524),
    error: Color(0xFFF75C5C),
    errorSubtle: Color(0x26F75C5C),
    info: Color(0xFF4C9AFF),
    infoSubtle: Color(0x264C9AFF),
    video: Color(0xFF9B7BFF),
    audio: Color(0xFF3DD68C),
    image: Color(0xFFF5A524),
    document: Color(0xFF4C9AFF),
    neutral: Color(0xFF8A919C),
    shadow: Color(0x66000000),
  );

  static const AppPalette light = AppPalette(
    windowBackground: Color(0xFFF4F5F7),
    sidebarBackground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0F1F4),
    surfaceHover: Color(0xFFF4F5F7),
    border: Color(0xFFE2E5EA),
    borderStrong: Color(0xFFCBD1DA),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF596270),
    textTertiary: Color(0xFF8A929E),
    accent: Color(0xFF5865F2),
    accentHover: Color(0xFF4753E0),
    accentSubtle: Color(0x1A5865F2),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF18A96B),
    successSubtle: Color(0x1A18A96B),
    warning: Color(0xFFD98008),
    warningSubtle: Color(0x1AD98008),
    error: Color(0xFFDC3838),
    errorSubtle: Color(0x1ADC3838),
    info: Color(0xFF2A7DE1),
    infoSubtle: Color(0x1A2A7DE1),
    video: Color(0xFF7C4DFF),
    audio: Color(0xFF18A96B),
    image: Color(0xFFD98008),
    document: Color(0xFF2A7DE1),
    neutral: Color(0xFF6B7280),
    shadow: Color(0x14000000),
  );

  @override
  AppPalette copyWith({
    Color? windowBackground,
    Color? sidebarBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? surfaceHover,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? onAccent,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? error,
    Color? errorSubtle,
    Color? info,
    Color? infoSubtle,
    Color? video,
    Color? audio,
    Color? image,
    Color? document,
    Color? neutral,
    Color? shadow,
  }) {
    return AppPalette(
      windowBackground: windowBackground ?? this.windowBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      error: error ?? this.error,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      video: video ?? this.video,
      audio: audio ?? this.audio,
      image: image ?? this.image,
      document: document ?? this.document,
      neutral: neutral ?? this.neutral,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      windowBackground: c(windowBackground, other.windowBackground),
      sidebarBackground: c(sidebarBackground, other.sidebarBackground),
      surface: c(surface, other.surface),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      onAccent: c(onAccent, other.onAccent),
      success: c(success, other.success),
      successSubtle: c(successSubtle, other.successSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      error: c(error, other.error),
      errorSubtle: c(errorSubtle, other.errorSubtle),
      info: c(info, other.info),
      infoSubtle: c(infoSubtle, other.infoSubtle),
      video: c(video, other.video),
      audio: c(audio, other.audio),
      image: c(image, other.image),
      document: c(document, other.document),
      neutral: c(neutral, other.neutral),
      shadow: c(shadow, other.shadow),
    );
  }
}
