import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

extension BuildContextX on BuildContext {
  /// Semantic colour tokens for the active theme.
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);

  /// True on a tablet-width screen, where a navigation rail and two-column
  /// content make sense. A phone in landscape stays below this.
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= AppSizes.tabletBreakpoint;

  /// True on a phone-width screen: single column, bottom navigation.
  bool get isPhone => !isTablet;

  /// True when content panels can sit side by side.
  bool get isWide => MediaQuery.sizeOf(this).width >= AppSizes.wideBreakpoint;

  /// True when vertical space is scarce, such as a phone held in landscape.
  bool get isShort => MediaQuery.sizeOf(this).height < 480;

  /// Safe-area inset at the bottom, used to keep sticky bars clear of the
  /// system gesture area.
  double get bottomInset => MediaQuery.viewPaddingOf(this).bottom;

  void showToast(String message, {IconData? icon, Color? accent}) {
    final AppPalette p = palette;
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: accent ?? p.accent),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
