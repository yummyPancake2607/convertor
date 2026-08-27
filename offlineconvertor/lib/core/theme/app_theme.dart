import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light/dark [ThemeData] from the [AppPalette] tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceElevated,
      outline: p.border,
      outlineVariant: p.border,
      shadow: p.shadow,
    );

    final TextTheme text = AppTypography.textTheme(
      p.textPrimary,
      p.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.windowBackground,
      canvasColor: p.windowBackground,
      textTheme: text,
      fontFamily: AppTypography.fontFamily,
      extensions: <ThemeExtension<dynamic>>[p],
      // Splash and highlight stay enabled: on a touch screen the ripple is the
      // only confirmation that a tap landed.
      splashFactory: InkSparkle.splashFactory,
      splashColor: p.accent.withValues(alpha: 0.10),
      highlightColor: p.accent.withValues(alpha: 0.06),
      hoverColor: p.surfaceHover,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      // Standard density, not compact: compact shrinks tap targets below the
      // 48dp accessibility minimum.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      tooltipTheme: TooltipThemeData(
        // On touch, tooltips appear on long-press rather than hover.
        waitDuration: const Duration(milliseconds: 300),
        showDuration: const Duration(seconds: 2),
        triggerMode: TooltipTriggerMode.longPress,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: p.borderStrong),
        ),
        textStyle: text.bodySmall?.copyWith(color: p.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.windowBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: p.textSecondary, size: 22),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBarHeight,
        backgroundColor: p.sidebarBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.accentSubtle,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? p.accent : p.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.textPrimary : p.textTertiary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.sidebarBackground,
        indicatorColor: p.accentSubtle,
        selectedIconTheme: IconThemeData(color: p.accent, size: 22),
        unselectedIconTheme: IconThemeData(color: p.textTertiary, size: 22),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: p.textTertiary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surfaceElevated,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        minVerticalPadding: AppSpacing.md,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(p.borderStrong),
        thickness: const WidgetStatePropertyAll<double>(4),
        radius: const Radius.circular(AppRadius.pill),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return p.accent.withValues(alpha: 0.35);
            }
            if (states.contains(WidgetState.hovered)) return p.accentHover;
            return p.accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return p.onAccent.withValues(alpha: 0.6);
            }
            return p.onAccent;
          }),
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return p.textTertiary;
            return p.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.hovered)) return p.surfaceHover;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.hovered)) {
              return BorderSide(color: p.borderStrong);
            }
            return BorderSide(color: p.border);
          }),
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(p.accent),
          overlayColor: WidgetStatePropertyAll<Color>(p.accentSubtle),
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.error),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: p.shadow,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: p.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return p.onAccent;
          return p.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return p.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return p.borderStrong;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceSunken,
        thumbColor: p.accent,
        overlayColor: p.accentSubtle,
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(p.onAccent),
        side: BorderSide(color: p.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceSunken,
        linearMinHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: text.bodyLarge?.copyWith(color: p.textPrimary),
        actionTextColor: p.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 12,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
    );
  }
}
