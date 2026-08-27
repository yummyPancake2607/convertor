import 'conversion_settings.dart';
import 'file_format.dart';
import 'file_info.dart';
import 'media_type.dart';

/// Everything the engine needs to perform one conversion.
///
/// This is the value that crosses into the C++ engine when a job is created.
/// It is immutable: once a job exists, changing settings means creating a new
/// request (which is what "retry with different options" does).
class ConversionRequest {
  const ConversionRequest({
    required this.input,
    required this.outputFormat,
    required this.outputPath,
    this.settings = const ConversionSettings(),
    this.overwriteExisting = false,
  });

  final FileInfo input;
  final FileFormat outputFormat;

  /// Absolute destination path, extension included.
  final String outputPath;

  final ConversionSettings settings;
  final bool overwriteExisting;

  FileFormat? get inputFormat => input.format;

  MediaType get inputMediaType => input.mediaType;

  MediaType get outputMediaType => outputFormat.mediaType;

  ConversionType get conversionType =>
      ConversionType.resolve(inputMediaType, outputMediaType);

  /// The settings group the engine will actually read for this conversion.
  ///
  /// Video -> audio reads the audio group even though the input is a video,
  /// which is why this is derived from the output type, with the video group
  /// layered on for true video output.
  String get relevantSettingsSummary => switch (conversionType) {
    ConversionType.videoToVideo => settings.video.summary,
    ConversionType.videoToAudio ||
    ConversionType.audioToAudio => settings.audio.summary,
    ConversionType.videoToImage ||
    ConversionType.imageToImage ||
    ConversionType.documentToImage => settings.image.summary,
    ConversionType.imageToDocument ||
    ConversionType.documentToDocument => settings.document.summary,
    ConversionType.unsupported => '',
  };

  ConversionRequest copyWith({
    FileInfo? input,
    FileFormat? outputFormat,
    String? outputPath,
    ConversionSettings? settings,
    bool? overwriteExisting,
  }) {
    return ConversionRequest(
      input: input ?? this.input,
      outputFormat: outputFormat ?? this.outputFormat,
      outputPath: outputPath ?? this.outputPath,
      settings: settings ?? this.settings,
      overwriteExisting: overwriteExisting ?? this.overwriteExisting,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'input': input.toJson(),
    'outputFormat': outputFormat.id,
    'outputPath': outputPath,
    'settings': settings.toJson(),
    'overwriteExisting': overwriteExisting,
  };
}
