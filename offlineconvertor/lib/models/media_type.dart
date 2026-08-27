import 'package:flutter/material.dart';

/// Top-level category of a file.
///
/// Mirrors the `MediaType` enum that the C++ engine will expose. The engine
/// picks a converter implementation from this value (FFmpeg / image library /
/// document subsystem), so the set must stay in sync across the FFI boundary.
enum MediaType {
  video,
  audio,
  image,
  document,
  unknown;

  String get label => switch (this) {
    MediaType.video => 'Video',
    MediaType.audio => 'Audio',
    MediaType.image => 'Image',
    MediaType.document => 'Document',
    MediaType.unknown => 'Unknown',
  };

  String get pluralLabel => switch (this) {
    // "Audio" is already a mass noun; "Audios" reads as a mistake.
    MediaType.audio => 'Audio',
    MediaType.unknown => 'Unknown files',
    _ => '${label}s',
  };

  IconData get icon => switch (this) {
    MediaType.video => Icons.movie_outlined,
    MediaType.audio => Icons.graphic_eq_rounded,
    MediaType.image => Icons.image_outlined,
    MediaType.document => Icons.description_outlined,
    MediaType.unknown => Icons.insert_drive_file_outlined,
  };

  /// Wire value used for persistence and (later) the FFI enum mapping.
  String get id => name;

  static MediaType fromId(String? id) => MediaType.values.firstWhere(
    (MediaType t) => t.name == id,
    orElse: () => MediaType.unknown,
  );

  /// Which engine subsystem handles this category.
  ///
  /// Purely informational in the UI today; it becomes the converter-selection
  /// key in the C++ engine.
  String get engineName => switch (this) {
    MediaType.video => 'FFmpeg',
    MediaType.audio => 'FFmpeg',
    MediaType.image => 'Image engine',
    MediaType.document => 'Document engine',
    MediaType.unknown => 'None',
  };
}

/// The kind of transformation a job performs.
///
/// This is distinct from [MediaType] because the interesting cases cross
/// categories: extracting an MP3 from an MP4 is a video input with an audio
/// output, and the engine must select the converter from the *pair*.
enum ConversionType {
  videoToVideo,
  videoToAudio,
  videoToImage,
  audioToAudio,
  imageToImage,
  imageToDocument,
  documentToDocument,
  documentToImage,
  unsupported;

  String get label => switch (this) {
    ConversionType.videoToVideo => 'Video transcode',
    ConversionType.videoToAudio => 'Audio extraction',
    ConversionType.videoToImage => 'Frame export',
    ConversionType.audioToAudio => 'Audio transcode',
    ConversionType.imageToImage => 'Image conversion',
    ConversionType.imageToDocument => 'Image to document',
    ConversionType.documentToDocument => 'Document conversion',
    ConversionType.documentToImage => 'Document render',
    ConversionType.unsupported => 'Unsupported',
  };

  bool get isSupported => this != ConversionType.unsupported;

  String get id => name;

  static ConversionType fromId(String? id) => ConversionType.values.firstWhere(
    (ConversionType t) => t.name == id,
    orElse: () => ConversionType.unsupported,
  );

  /// Resolves the conversion type from an input/output category pair.
  static ConversionType resolve(MediaType input, MediaType output) {
    return switch ((input, output)) {
      (MediaType.video, MediaType.video) => ConversionType.videoToVideo,
      (MediaType.video, MediaType.audio) => ConversionType.videoToAudio,
      (MediaType.video, MediaType.image) => ConversionType.videoToImage,
      (MediaType.audio, MediaType.audio) => ConversionType.audioToAudio,
      (MediaType.image, MediaType.image) => ConversionType.imageToImage,
      (MediaType.image, MediaType.document) => ConversionType.imageToDocument,
      (MediaType.document, MediaType.document) =>
        ConversionType.documentToDocument,
      (MediaType.document, MediaType.image) => ConversionType.documentToImage,
      _ => ConversionType.unsupported,
    };
  }
}
