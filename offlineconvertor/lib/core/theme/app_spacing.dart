/// Spacing scale (4pt base) and shared geometry constants.
///
/// Using a fixed scale everywhere is what keeps the desktop layout feeling
/// deliberate rather than hand-tuned per screen.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 22;
  static const double pill = 999;
}

abstract final class AppSizes {
  /// Minimum size for anything tappable. Android's accessibility guidance is
  /// 48dp, and every interactive widget in the app is checked against it.
  static const double touchTarget = 48;

  /// Bottom navigation bar height.
  static const double navBarHeight = 64;

  /// Width of the navigation rail used instead of the bottom bar on tablets.
  static const double navRailWidth = 88;

  /// At or above this width a navigation rail replaces the bottom bar, and
  /// two-column content becomes worthwhile. Phones in landscape stay below it.
  static const double tabletBreakpoint = 720;

  /// At or above this width content panels can sit side by side.
  static const double wideBreakpoint = 1000;

  static const double controlHeight = 48;
  static const double controlHeightSmall = 40;
  static const double maxContentWidth = 720;
}
