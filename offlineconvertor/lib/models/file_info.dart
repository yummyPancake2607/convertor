import '../core/constants/format_catalog.dart';
import '../core/utils/path_utils.dart';
import 'file_format.dart';
import 'media_type.dart';

/// A file the user has selected, plus whatever the application has been able to
/// learn about it.
///
/// Today [format] is resolved from the extension. In Stage 2 the C++ engine's
/// format detector will inspect the container/magic bytes and return a richer
/// probe result; this model already carries the optional media metadata fields
/// that probe will fill in, so the UI will not need to change.
class FileInfo {
  const FileInfo({
    required this.path,
    required this.sizeBytes,
    this.format,
    this.duration,
    this.width,
    this.height,
    this.pageCount,
    this.videoCodec,
    this.audioCodec,
    this.frameRate,
    this.probeFailed = false,
  });

  final String path;
  final int sizeBytes;

  /// Null when the extension is not in the catalogue.
  final FileFormat? format;

  // --- Optional probe metadata (populated by the engine in Stage 2) ---
  final Duration? duration;
  final int? width;
  final int? height;
  final int? pageCount;
  final String? videoCodec;
  final String? audioCodec;
  final double? frameRate;

  /// The engine could not read the file (corrupt / unreadable).
  final bool probeFailed;

  String get name => PathUtils.fileName(path);
  String get baseName => PathUtils.fileNameWithoutExtension(path);
  String get directory => PathUtils.directory(path);
  String get extension => PathUtils.extension(path);

  MediaType get mediaType => format?.mediaType ?? MediaType.unknown;

  /// The application knows this format and can use it as an input.
  bool get isSupported => format != null && format!.canRead;

  /// Output formats offered for this file.
  List<FileFormat> get availableOutputs =>
      format == null ? const <FileFormat>[] : FormatCatalog.outputsFor(format!);

  /// "1920 x 1080" when known.
  String? get dimensionsLabel =>
      (width != null && height != null) ? '$width x $height' : null;

  FileInfo copyWith({
    String? path,
    int? sizeBytes,
    FileFormat? format,
    Duration? duration,
    int? width,
    int? height,
    int? pageCount,
    String? videoCodec,
    String? audioCodec,
    double? frameRate,
    bool? probeFailed,
  }) {
    return FileInfo(
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      format: format ?? this.format,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      pageCount: pageCount ?? this.pageCount,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      frameRate: frameRate ?? this.frameRate,
      probeFailed: probeFailed ?? this.probeFailed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'sizeBytes': sizeBytes,
    'format': format?.id,
    'durationMs': duration?.inMilliseconds,
    'width': width,
    'height': height,
    'pageCount': pageCount,
    'videoCodec': videoCodec,
    'audioCodec': audioCodec,
    'frameRate': frameRate,
  };

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    final int? durationMs = json['durationMs'] as int?;
    return FileInfo(
      path: json['path'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      format: FormatCatalog.fromId(json['format'] as String?),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      width: json['width'] as int?,
      height: json['height'] as int?,
      pageCount: json['pageCount'] as int?,
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String?,
      frameRate: (json['frameRate'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) => other is FileInfo && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
