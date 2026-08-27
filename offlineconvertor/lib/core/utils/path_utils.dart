import 'package:path/path.dart' as p;

/// Filesystem path helpers.
///
/// The C++ engine will own the authoritative output-path resolution (including
/// collision handling), but the UI needs to *preview* the destination path
/// before a job runs, so the same rules are implemented here.
abstract final class PathUtils {
  static String fileName(String path) => p.basename(path);

  static String fileNameWithoutExtension(String path) =>
      p.basenameWithoutExtension(path);

  static String directory(String path) => p.dirname(path);

  /// Extension without the leading dot, lowercased. Empty when absent.
  static String extension(String path) {
    final String ext = p.extension(path);
    if (ext.isEmpty) return '';
    return ext.substring(1).toLowerCase();
  }

  static String join(String directory, String name) => p.join(directory, name);

  /// Builds the destination path for a conversion.
  ///
  /// [suffix] is appended before the extension when the caller wants to avoid
  /// clobbering a same-named file (`clip.mp4` -> `clip_1.mp4`).
  static String buildOutputPath({
    required String inputPath,
    required String outputExtension,
    required String outputDirectory,
    String suffix = '',
  }) {
    final String base = fileNameWithoutExtension(inputPath);
    final String dir = outputDirectory.isEmpty
        ? directory(inputPath)
        : outputDirectory;
    return p.join(dir, '$base$suffix.$outputExtension');
  }

  /// Collapses a long path for display: keeps the first and last segments.
  static String compact(String path, {int maxSegments = 3}) {
    final List<String> parts = p.split(path);
    if (parts.length <= maxSegments + 1) return path;
    return p.joinAll(<String>[
      parts.first,
      '...',
      ...parts.sublist(parts.length - maxSegments),
    ]);
  }

  /// Replaces the user's home directory with `~` for compact display.
  static String withTilde(String path, String? home) {
    if (home == null || home.isEmpty) return path;
    if (path == home) return '~';
    if (path.startsWith('$home${p.separator}')) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }
}
