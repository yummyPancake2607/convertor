import 'package:intl/intl.dart';

/// Display formatting helpers. Kept out of widgets so the same rules apply
/// everywhere (dashboard, queue, history).
abstract final class Formatters {
  static final NumberFormat _compact = NumberFormat.compact();

  /// 1023 -> "1023 B", 2_500_000 -> "2.4 MB"
  static String fileSize(int bytes) {
    if (bytes < 0) return '--';
    if (bytes < 1024) return '$bytes B';
    const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024;
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final String formatted = value >= 100
        ? value.toStringAsFixed(0)
        : value >= 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);
    return '$formatted ${units[unit]}';
  }

  /// 0.735 -> "74%"
  static String percent(double fraction) =>
      '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

  static String count(int value) =>
      value < 10000 ? '$value' : _compact.format(value);

  /// 3725 seconds -> "1:02:05"
  static String duration(Duration d) {
    if (d.inSeconds < 0) return '--';
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);
    final String mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// Short elapsed/remaining label: "8s", "1m 24s", "2h 05m"
  static String shortDuration(Duration d) {
    if (d.inSeconds < 1) return '<1s';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) {
      final int s = d.inSeconds.remainder(60);
      return s == 0 ? '${d.inMinutes}m' : '${d.inMinutes}m ${s}s';
    }
    final int m = d.inMinutes.remainder(60);
    return '${d.inHours}h ${m.toString().padLeft(2, '0')}m';
  }

  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _timeOnly = DateFormat('HH:mm');
  static final DateFormat _dayMonth = DateFormat('d MMM');

  static String dateTime(DateTime value) => _dateTime.format(value);

  /// "14:22" today, "3 Feb" this year, "3 Feb 2024" otherwise.
  static String smartDate(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(value.year, value.month, value.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today, ${_timeOnly.format(value)}';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_timeOnly.format(value)}';
    }
    if (value.year == now.year) return _dayMonth.format(value);
    return _dateTime.format(value);
  }

  /// "just now", "4 min ago", "2 h ago", "5 d ago"
  static String relative(DateTime value) {
    final Duration diff = DateTime.now().difference(value);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return smartDate(value);
  }

  /// Bitrate in kbps -> "192 kbps" / "1.5 Mbps"
  static String bitrate(int kbps) {
    if (kbps >= 1000) {
      return '${(kbps / 1000).toStringAsFixed(kbps % 1000 == 0 ? 0 : 1)} Mbps';
    }
    return '$kbps kbps';
  }

  /// 44100 -> "44.1 kHz"
  static String sampleRate(int hz) {
    final double khz = hz / 1000;
    return '${khz.toStringAsFixed(khz == khz.roundToDouble() ? 0 : 1)} kHz';
  }
}
