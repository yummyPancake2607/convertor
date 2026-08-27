// Per-job conversion options.
//
// The settings are split by media category so each form only deals with what
// is relevant, and so the C++ engine can map each group onto the arguments of
// the tool that actually performs the work (FFmpeg flags, image-library
// parameters, document-engine filters).
//
// Every field is nullable-or-defaulted in a way that means "let the engine
// decide": `null` / `keepOriginal` must produce a sensible automatic choice
// rather than an error.

// -----------------------------------------------------------------------------
// Shared enums
// -----------------------------------------------------------------------------

enum QualityPreset {
  low,
  medium,
  high,
  veryHigh,
  lossless;

  String get label => switch (this) {
    QualityPreset.low => 'Low',
    QualityPreset.medium => 'Medium',
    QualityPreset.high => 'High',
    QualityPreset.veryHigh => 'Very high',
    QualityPreset.lossless => 'Lossless',
  };

  String get hint => switch (this) {
    QualityPreset.low => 'Smallest file, visible loss',
    QualityPreset.medium => 'Balanced size and quality',
    QualityPreset.high => 'Recommended for most files',
    QualityPreset.veryHigh => 'Near-original, larger file',
    QualityPreset.lossless => 'No quality loss, largest file',
  };

  String get id => name;

  static QualityPreset fromId(String? id) => QualityPreset.values.firstWhere(
    (QualityPreset q) => q.name == id,
    orElse: () => QualityPreset.high,
  );
}

enum EncodingSpeed {
  veryFast,
  fast,
  balanced,
  slow;

  String get label => switch (this) {
    EncodingSpeed.veryFast => 'Very fast',
    EncodingSpeed.fast => 'Fast',
    EncodingSpeed.balanced => 'Balanced',
    EncodingSpeed.slow => 'Slow (best compression)',
  };

  String get id => name;

  static EncodingSpeed fromId(String? id) => EncodingSpeed.values.firstWhere(
    (EncodingSpeed s) => s.name == id,
    orElse: () => EncodingSpeed.balanced,
  );
}

enum ResolutionPreset {
  keepOriginal,
  uhd2160p,
  qhd1440p,
  fhd1080p,
  hd720p,
  sd480p,
  sd360p;

  String get label => switch (this) {
    ResolutionPreset.keepOriginal => 'Keep original',
    ResolutionPreset.uhd2160p => '2160p (4K UHD)',
    ResolutionPreset.qhd1440p => '1440p (QHD)',
    ResolutionPreset.fhd1080p => '1080p (Full HD)',
    ResolutionPreset.hd720p => '720p (HD)',
    ResolutionPreset.sd480p => '480p',
    ResolutionPreset.sd360p => '360p',
  };

  /// Target height in pixels; null means "do not scale".
  int? get height => switch (this) {
    ResolutionPreset.keepOriginal => null,
    ResolutionPreset.uhd2160p => 2160,
    ResolutionPreset.qhd1440p => 1440,
    ResolutionPreset.fhd1080p => 1080,
    ResolutionPreset.hd720p => 720,
    ResolutionPreset.sd480p => 480,
    ResolutionPreset.sd360p => 360,
  };

  String get id => name;

  static ResolutionPreset fromId(String? id) =>
      ResolutionPreset.values.firstWhere(
        (ResolutionPreset r) => r.name == id,
        orElse: () => ResolutionPreset.keepOriginal,
      );
}

enum AudioChannels {
  keepOriginal,
  mono,
  stereo;

  String get label => switch (this) {
    AudioChannels.keepOriginal => 'Keep original',
    AudioChannels.mono => 'Mono (1)',
    AudioChannels.stereo => 'Stereo (2)',
  };

  int? get count => switch (this) {
    AudioChannels.keepOriginal => null,
    AudioChannels.mono => 1,
    AudioChannels.stereo => 2,
  };

  String get id => name;

  static AudioChannels fromId(String? id) => AudioChannels.values.firstWhere(
    (AudioChannels c) => c.name == id,
    orElse: () => AudioChannels.keepOriginal,
  );
}

/// How a resize should treat the source aspect ratio.
enum ResizeMode {
  fit,
  fill,
  stretch;

  String get label => switch (this) {
    ResizeMode.fit => 'Fit inside',
    ResizeMode.fill => 'Fill and crop',
    ResizeMode.stretch => 'Stretch',
  };

  String get hint => switch (this) {
    ResizeMode.fit => 'Whole image fits, aspect ratio kept',
    ResizeMode.fill => 'Fills the box, edges cropped',
    ResizeMode.stretch => 'Exact size, aspect ratio ignored',
  };

  String get id => name;

  static ResizeMode fromId(String? id) => ResizeMode.values.firstWhere(
    (ResizeMode m) => m.name == id,
    orElse: () => ResizeMode.fit,
  );
}

enum PdfPageRangeMode {
  allPages,
  custom;

  String get label => switch (this) {
    PdfPageRangeMode.allPages => 'All pages',
    PdfPageRangeMode.custom => 'Page range',
  };

  String get id => name;

  static PdfPageRangeMode fromId(String? id) =>
      PdfPageRangeMode.values.firstWhere(
        (PdfPageRangeMode m) => m.name == id,
        orElse: () => PdfPageRangeMode.allPages,
      );
}

// -----------------------------------------------------------------------------
// Video
// -----------------------------------------------------------------------------

class VideoSettings {
  const VideoSettings({
    this.quality = QualityPreset.high,
    this.resolution = ResolutionPreset.keepOriginal,
    this.videoCodec,
    this.videoBitrateKbps,
    this.frameRate,
    this.speed = EncodingSpeed.balanced,
    this.stripAudio = false,
    this.copyStreamsWhenPossible = true,
  });

  final QualityPreset quality;
  final ResolutionPreset resolution;

  /// Null means "engine default for the target container".
  final String? videoCodec;

  /// Null means quality-based (CRF-style) encoding rather than a target rate.
  final int? videoBitrateKbps;

  /// Null means keep the source frame rate.
  final double? frameRate;

  final EncodingSpeed speed;
  final bool stripAudio;

  /// Remux instead of re-encoding when the source streams are already
  /// compatible with the target container. Enormous speed win for e.g.
  /// MKV -> MP4, so it defaults on.
  final bool copyStreamsWhenPossible;

  static const List<String> availableCodecs = <String>[
    'h264',
    'h265',
    'vp9',
    'av1',
    'mpeg4',
    'theora',
  ];

  static const List<int> bitratePresets = <int>[
    1000,
    2000,
    4000,
    6000,
    8000,
    12000,
    20000,
  ];

  static const List<double> frameRatePresets = <double>[
    23.976,
    24,
    25,
    29.97,
    30,
    50,
    60,
  ];

  VideoSettings copyWith({
    QualityPreset? quality,
    ResolutionPreset? resolution,
    String? videoCodec,
    bool clearVideoCodec = false,
    int? videoBitrateKbps,
    bool clearVideoBitrate = false,
    double? frameRate,
    bool clearFrameRate = false,
    EncodingSpeed? speed,
    bool? stripAudio,
    bool? copyStreamsWhenPossible,
  }) {
    return VideoSettings(
      quality: quality ?? this.quality,
      resolution: resolution ?? this.resolution,
      videoCodec: clearVideoCodec ? null : (videoCodec ?? this.videoCodec),
      videoBitrateKbps: clearVideoBitrate
          ? null
          : (videoBitrateKbps ?? this.videoBitrateKbps),
      frameRate: clearFrameRate ? null : (frameRate ?? this.frameRate),
      speed: speed ?? this.speed,
      stripAudio: stripAudio ?? this.stripAudio,
      copyStreamsWhenPossible:
          copyStreamsWhenPossible ?? this.copyStreamsWhenPossible,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'quality': quality.id,
    'resolution': resolution.id,
    'videoCodec': videoCodec,
    'videoBitrateKbps': videoBitrateKbps,
    'frameRate': frameRate,
    'speed': speed.id,
    'stripAudio': stripAudio,
    'copyStreams': copyStreamsWhenPossible,
  };

  factory VideoSettings.fromJson(Map<String, dynamic> json) => VideoSettings(
    quality: QualityPreset.fromId(json['quality'] as String?),
    resolution: ResolutionPreset.fromId(json['resolution'] as String?),
    videoCodec: json['videoCodec'] as String?,
    videoBitrateKbps: json['videoBitrateKbps'] as int?,
    frameRate: (json['frameRate'] as num?)?.toDouble(),
    speed: EncodingSpeed.fromId(json['speed'] as String?),
    stripAudio: json['stripAudio'] as bool? ?? false,
    copyStreamsWhenPossible: json['copyStreams'] as bool? ?? true,
  );

  /// Short human summary shown on job cards.
  String get summary {
    final List<String> parts = <String>[quality.label];
    if (resolution != ResolutionPreset.keepOriginal) {
      parts.add(resolution.label.split(' ').first);
    }
    if (videoCodec != null) parts.add(videoCodec!.toUpperCase());
    if (stripAudio) parts.add('no audio');
    return parts.join(' - ');
  }
}

// -----------------------------------------------------------------------------
// Audio
// -----------------------------------------------------------------------------

class AudioSettings {
  const AudioSettings({
    this.quality = QualityPreset.high,
    this.audioCodec,
    this.bitrateKbps,
    this.sampleRateHz,
    this.channels = AudioChannels.keepOriginal,
    this.normalizeLoudness = false,
  });

  final QualityPreset quality;
  final String? audioCodec;

  /// Null means derive from [quality].
  final int? bitrateKbps;

  /// Null means keep the source sample rate.
  final int? sampleRateHz;

  final AudioChannels channels;
  final bool normalizeLoudness;

  static const List<String> availableCodecs = <String>[
    'aac',
    'mp3',
    'flac',
    'opus',
    'vorbis',
    'pcm_s16le',
  ];

  static const List<int> bitratePresets = <int>[
    64,
    96,
    128,
    160,
    192,
    256,
    320,
  ];

  static const List<int> sampleRatePresets = <int>[
    22050,
    32000,
    44100,
    48000,
    96000,
  ];

  /// Bitrate implied by the quality preset when none is set explicitly.
  int get effectiveBitrateKbps =>
      bitrateKbps ??
      switch (quality) {
        QualityPreset.low => 96,
        QualityPreset.medium => 128,
        QualityPreset.high => 192,
        QualityPreset.veryHigh => 320,
        QualityPreset.lossless => 320,
      };

  AudioSettings copyWith({
    QualityPreset? quality,
    String? audioCodec,
    bool clearAudioCodec = false,
    int? bitrateKbps,
    bool clearBitrate = false,
    int? sampleRateHz,
    bool clearSampleRate = false,
    AudioChannels? channels,
    bool? normalizeLoudness,
  }) {
    return AudioSettings(
      quality: quality ?? this.quality,
      audioCodec: clearAudioCodec ? null : (audioCodec ?? this.audioCodec),
      bitrateKbps: clearBitrate ? null : (bitrateKbps ?? this.bitrateKbps),
      sampleRateHz: clearSampleRate
          ? null
          : (sampleRateHz ?? this.sampleRateHz),
      channels: channels ?? this.channels,
      normalizeLoudness: normalizeLoudness ?? this.normalizeLoudness,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'quality': quality.id,
    'audioCodec': audioCodec,
    'bitrateKbps': bitrateKbps,
    'sampleRateHz': sampleRateHz,
    'channels': channels.id,
    'normalizeLoudness': normalizeLoudness,
  };

  factory AudioSettings.fromJson(Map<String, dynamic> json) => AudioSettings(
    quality: QualityPreset.fromId(json['quality'] as String?),
    audioCodec: json['audioCodec'] as String?,
    bitrateKbps: json['bitrateKbps'] as int?,
    sampleRateHz: json['sampleRateHz'] as int?,
    channels: AudioChannels.fromId(json['channels'] as String?),
    normalizeLoudness: json['normalizeLoudness'] as bool? ?? false,
  );

  String get summary {
    final List<String> parts = <String>['$effectiveBitrateKbps kbps'];
    if (sampleRateHz != null) {
      parts.add('${(sampleRateHz! / 1000).toStringAsFixed(1)} kHz');
    }
    if (channels != AudioChannels.keepOriginal) {
      parts.add(channels.label.split(' ').first.toLowerCase());
    }
    return parts.join(' - ');
  }
}

// -----------------------------------------------------------------------------
// Image
// -----------------------------------------------------------------------------

class ImageSettings {
  const ImageSettings({
    this.quality = 90,
    this.width,
    this.height,
    this.resizeMode = ResizeMode.fit,
    this.preserveMetadata = false,
    this.stripAlpha = false,
    this.dpi,
    this.lossless = false,
  });

  /// 1-100 encoder quality. Ignored for lossless formats.
  final int quality;

  /// Null on both axes means "do not resize". One axis set means the other is
  /// derived from the aspect ratio.
  final int? width;
  final int? height;

  final ResizeMode resizeMode;
  final bool preserveMetadata;

  /// Flatten transparency onto a background. Required for JPEG output.
  final bool stripAlpha;

  final int? dpi;

  /// Use the lossless mode of formats that support both (WebP, AVIF).
  final bool lossless;

  bool get hasResize => width != null || height != null;

  static const List<int> qualityPresets = <int>[60, 75, 85, 90, 95, 100];

  ImageSettings copyWith({
    int? quality,
    int? width,
    bool clearWidth = false,
    int? height,
    bool clearHeight = false,
    ResizeMode? resizeMode,
    bool? preserveMetadata,
    bool? stripAlpha,
    int? dpi,
    bool clearDpi = false,
    bool? lossless,
  }) {
    return ImageSettings(
      quality: quality ?? this.quality,
      width: clearWidth ? null : (width ?? this.width),
      height: clearHeight ? null : (height ?? this.height),
      resizeMode: resizeMode ?? this.resizeMode,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      stripAlpha: stripAlpha ?? this.stripAlpha,
      dpi: clearDpi ? null : (dpi ?? this.dpi),
      lossless: lossless ?? this.lossless,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'quality': quality,
    'width': width,
    'height': height,
    'resizeMode': resizeMode.id,
    'preserveMetadata': preserveMetadata,
    'stripAlpha': stripAlpha,
    'dpi': dpi,
    'lossless': lossless,
  };

  factory ImageSettings.fromJson(Map<String, dynamic> json) => ImageSettings(
    quality: json['quality'] as int? ?? 90,
    width: json['width'] as int?,
    height: json['height'] as int?,
    resizeMode: ResizeMode.fromId(json['resizeMode'] as String?),
    preserveMetadata: json['preserveMetadata'] as bool? ?? false,
    stripAlpha: json['stripAlpha'] as bool? ?? false,
    dpi: json['dpi'] as int?,
    lossless: json['lossless'] as bool? ?? false,
  );

  String get summary {
    final List<String> parts = <String>[];
    if (lossless) {
      parts.add('lossless');
    } else {
      parts.add('q$quality');
    }
    if (hasResize) {
      parts.add('${width ?? 'auto'} x ${height ?? 'auto'}');
    }
    return parts.join(' - ');
  }
}

// -----------------------------------------------------------------------------
// Document
// -----------------------------------------------------------------------------

class DocumentSettings {
  const DocumentSettings({
    this.pageRangeMode = PdfPageRangeMode.allPages,
    this.pageRange = '',
    this.renderDpi = 150,
    this.embedFonts = true,
    this.singleFileOutput = true,
  });

  final PdfPageRangeMode pageRangeMode;

  /// Free-form range like `1-3,7,10-`. Only meaningful for
  /// [PdfPageRangeMode.custom].
  final String pageRange;

  /// Rasterisation density for document -> image conversions.
  final int renderDpi;

  final bool embedFonts;

  /// For document -> image: one file per page when false.
  final bool singleFileOutput;

  static const List<int> dpiPresets = <int>[72, 96, 150, 200, 300, 600];

  DocumentSettings copyWith({
    PdfPageRangeMode? pageRangeMode,
    String? pageRange,
    int? renderDpi,
    bool? embedFonts,
    bool? singleFileOutput,
  }) {
    return DocumentSettings(
      pageRangeMode: pageRangeMode ?? this.pageRangeMode,
      pageRange: pageRange ?? this.pageRange,
      renderDpi: renderDpi ?? this.renderDpi,
      embedFonts: embedFonts ?? this.embedFonts,
      singleFileOutput: singleFileOutput ?? this.singleFileOutput,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageRangeMode': pageRangeMode.id,
    'pageRange': pageRange,
    'renderDpi': renderDpi,
    'embedFonts': embedFonts,
    'singleFileOutput': singleFileOutput,
  };

  factory DocumentSettings.fromJson(Map<String, dynamic> json) =>
      DocumentSettings(
        pageRangeMode: PdfPageRangeMode.fromId(
          json['pageRangeMode'] as String?,
        ),
        pageRange: json['pageRange'] as String? ?? '',
        renderDpi: json['renderDpi'] as int? ?? 150,
        embedFonts: json['embedFonts'] as bool? ?? true,
        singleFileOutput: json['singleFileOutput'] as bool? ?? true,
      );

  String get summary {
    final List<String> parts = <String>['$renderDpi DPI'];
    if (pageRangeMode == PdfPageRangeMode.custom && pageRange.isNotEmpty) {
      parts.add('pages $pageRange');
    }
    return parts.join(' - ');
  }
}

// -----------------------------------------------------------------------------
// Aggregate
// -----------------------------------------------------------------------------

/// All conversion options for one job.
///
/// A single aggregate is carried by every job regardless of media type: the
/// converter that runs only reads the group it cares about. This keeps the FFI
/// struct one shape instead of a tagged union.
class ConversionSettings {
  const ConversionSettings({
    this.video = const VideoSettings(),
    this.audio = const AudioSettings(),
    this.image = const ImageSettings(),
    this.document = const DocumentSettings(),
  });

  final VideoSettings video;
  final AudioSettings audio;
  final ImageSettings image;
  final DocumentSettings document;

  ConversionSettings copyWith({
    VideoSettings? video,
    AudioSettings? audio,
    ImageSettings? image,
    DocumentSettings? document,
  }) {
    return ConversionSettings(
      video: video ?? this.video,
      audio: audio ?? this.audio,
      image: image ?? this.image,
      document: document ?? this.document,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'video': video.toJson(),
    'audio': audio.toJson(),
    'image': image.toJson(),
    'document': document.toJson(),
  };

  factory ConversionSettings.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) =>
        (json[key] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return ConversionSettings(
      video: VideoSettings.fromJson(sub('video')),
      audio: AudioSettings.fromJson(sub('audio')),
      image: ImageSettings.fromJson(sub('image')),
      document: DocumentSettings.fromJson(sub('document')),
    );
  }
}
