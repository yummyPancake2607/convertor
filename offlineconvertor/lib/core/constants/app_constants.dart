/// Fixed application metadata and tuning constants.
abstract final class AppConstants {
  static const String appName = 'Convertor';
  static const String appTagline = 'Offline universal file converter';
  static const String appVersion = '1.0.0';

  /// Default window geometry on desktop.
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 820;
  static const double minWindowWidth = 900;
  static const double minWindowHeight = 620;

  /// Recent conversions shown on the dashboard.
  static const int dashboardRecentCount = 6;

  /// Upper bound on files accepted in one drop/pick, to keep the UI responsive.
  static const int maxFilesPerBatch = 500;

  static const Duration shortAnimation = Duration(milliseconds: 140);
  static const Duration mediumAnimation = Duration(milliseconds: 220);
}
