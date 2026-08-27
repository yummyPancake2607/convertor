import 'media_type.dart';

/// A concrete container/encoding format the application knows about.
///
/// [id] is the canonical lowercase identifier (also the default extension) and
/// is the value crossing the FFI boundary later. [aliases] lists alternative
/// extensions that map onto the same format (`jpeg` -> `jpg`).
class FileFormat {
  const FileFormat({
    required this.id,
    required this.label,
    required this.mediaType,
    required this.mimeType,
    this.aliases = const <String>[],
    this.description = '',
    this.canRead = true,
    this.canWrite = true,
    this.isLossless = false,
  });

  final String id;
  final String label;
  final MediaType mediaType;
  final String mimeType;
  final List<String> aliases;
  final String description;

  /// The engine can use this format as an input.
  final bool canRead;

  /// The engine can produce this format as an output.
  final bool canWrite;

  final bool isLossless;

  /// Default filename extension (without the dot).
  String get extension => id;

  /// Uppercase form used in badges and format pickers.
  String get badge => id.toUpperCase();

  /// All extensions that resolve to this format.
  List<String> get allExtensions => <String>[id, ...aliases];

  @override
  bool operator ==(Object other) => other is FileFormat && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FileFormat($id)';
}
