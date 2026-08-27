import '../../models/file_format.dart';
import '../../models/media_type.dart';

/// The single source of truth for known formats and which conversions the
/// application offers.
///
/// The C++ engine will own the authoritative version of this table (built from
/// what FFmpeg / the image library / the document engine actually report at
/// runtime). Until then the catalogue lives here and the UI reads it through
/// the same shape it will later receive over FFI: "given this input format,
/// what output formats are available?"
abstract final class FormatCatalog {
  // ---------------------------------------------------------------------------
  // Video
  // ---------------------------------------------------------------------------
  static const FileFormat mp4 = FileFormat(
    id: 'mp4',
    label: 'MP4',
    mediaType: MediaType.video,
    mimeType: 'video/mp4',
    description: 'Universal container. Best compatibility.',
  );
  static const FileFormat mkv = FileFormat(
    id: 'mkv',
    label: 'Matroska',
    mediaType: MediaType.video,
    mimeType: 'video/x-matroska',
    description: 'Flexible container, multiple tracks and subtitles.',
  );
  static const FileFormat avi = FileFormat(
    id: 'avi',
    label: 'AVI',
    mediaType: MediaType.video,
    mimeType: 'video/x-msvideo',
    description: 'Legacy Windows container.',
  );
  static const FileFormat mov = FileFormat(
    id: 'mov',
    label: 'QuickTime',
    mediaType: MediaType.video,
    mimeType: 'video/quicktime',
    description: 'Apple container, common from cameras.',
  );
  static const FileFormat webm = FileFormat(
    id: 'webm',
    label: 'WebM',
    mediaType: MediaType.video,
    mimeType: 'video/webm',
    description: 'Open, web-optimised (VP9 / AV1).',
  );
  static const FileFormat flv = FileFormat(
    id: 'flv',
    label: 'Flash Video',
    mediaType: MediaType.video,
    mimeType: 'video/x-flv',
    description: 'Legacy streaming container.',
  );
  static const FileFormat wmv = FileFormat(
    id: 'wmv',
    label: 'WMV',
    mediaType: MediaType.video,
    mimeType: 'video/x-ms-wmv',
    description: 'Windows Media container.',
  );
  static const FileFormat threeGp = FileFormat(
    id: '3gp',
    label: '3GP',
    mediaType: MediaType.video,
    mimeType: 'video/3gpp',
    description: 'Mobile container, small files.',
  );
  static const FileFormat mpeg = FileFormat(
    id: 'mpeg',
    label: 'MPEG',
    mediaType: MediaType.video,
    mimeType: 'video/mpeg',
    aliases: <String>['mpg'],
    description: 'MPEG program stream.',
  );
  static const FileFormat m4v = FileFormat(
    id: 'm4v',
    label: 'M4V',
    mediaType: MediaType.video,
    mimeType: 'video/x-m4v',
    description: 'Apple MP4 variant.',
  );
  static const FileFormat ts = FileFormat(
    id: 'ts',
    label: 'MPEG-TS',
    mediaType: MediaType.video,
    mimeType: 'video/mp2t',
    aliases: <String>['mts', 'm2ts'],
    description: 'Transport stream, broadcast and cameras.',
  );
  static const FileFormat ogv = FileFormat(
    id: 'ogv',
    label: 'Ogg Video',
    mediaType: MediaType.video,
    mimeType: 'video/ogg',
    description: 'Ogg container with Theora video.',
  );

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------
  static const FileFormat mp3 = FileFormat(
    id: 'mp3',
    label: 'MP3',
    mediaType: MediaType.audio,
    mimeType: 'audio/mpeg',
    description: 'Universal lossy audio.',
  );
  static const FileFormat wav = FileFormat(
    id: 'wav',
    label: 'WAV',
    mediaType: MediaType.audio,
    mimeType: 'audio/wav',
    isLossless: true,
    description: 'Uncompressed PCM. Large files.',
  );
  static const FileFormat aac = FileFormat(
    id: 'aac',
    label: 'AAC',
    mediaType: MediaType.audio,
    mimeType: 'audio/aac',
    description: 'Efficient lossy audio.',
  );
  static const FileFormat flac = FileFormat(
    id: 'flac',
    label: 'FLAC',
    mediaType: MediaType.audio,
    mimeType: 'audio/flac',
    isLossless: true,
    description: 'Lossless compression.',
  );
  static const FileFormat ogg = FileFormat(
    id: 'ogg',
    label: 'Ogg Vorbis',
    mediaType: MediaType.audio,
    mimeType: 'audio/ogg',
    description: 'Open lossy audio.',
  );
  static const FileFormat m4a = FileFormat(
    id: 'm4a',
    label: 'M4A',
    mediaType: MediaType.audio,
    mimeType: 'audio/mp4',
    description: 'AAC in an MP4 container.',
  );
  static const FileFormat opus = FileFormat(
    id: 'opus',
    label: 'Opus',
    mediaType: MediaType.audio,
    mimeType: 'audio/opus',
    description: 'Modern low-bitrate codec.',
  );
  static const FileFormat wma = FileFormat(
    id: 'wma',
    label: 'WMA',
    mediaType: MediaType.audio,
    mimeType: 'audio/x-ms-wma',
    canWrite: false,
    description: 'Windows Media Audio. Read only.',
  );
  static const FileFormat aiff = FileFormat(
    id: 'aiff',
    label: 'AIFF',
    mediaType: MediaType.audio,
    mimeType: 'audio/aiff',
    aliases: <String>['aif'],
    isLossless: true,
    description: 'Uncompressed Apple audio.',
  );

  // ---------------------------------------------------------------------------
  // Image
  // ---------------------------------------------------------------------------
  static const FileFormat jpg = FileFormat(
    id: 'jpg',
    label: 'JPEG',
    mediaType: MediaType.image,
    mimeType: 'image/jpeg',
    aliases: <String>['jpeg', 'jpe'],
    description: 'Lossy photos. No transparency.',
  );
  static const FileFormat png = FileFormat(
    id: 'png',
    label: 'PNG',
    mediaType: MediaType.image,
    mimeType: 'image/png',
    isLossless: true,
    description: 'Lossless with transparency.',
  );
  static const FileFormat webpFormat = FileFormat(
    id: 'webp',
    label: 'WebP',
    mediaType: MediaType.image,
    mimeType: 'image/webp',
    description: 'Modern web format, lossy or lossless.',
  );
  static const FileFormat gif = FileFormat(
    id: 'gif',
    label: 'GIF',
    mediaType: MediaType.image,
    mimeType: 'image/gif',
    description: '256 colours, supports animation.',
  );
  static const FileFormat bmp = FileFormat(
    id: 'bmp',
    label: 'BMP',
    mediaType: MediaType.image,
    mimeType: 'image/bmp',
    isLossless: true,
    description: 'Uncompressed bitmap.',
  );
  static const FileFormat tiff = FileFormat(
    id: 'tiff',
    label: 'TIFF',
    mediaType: MediaType.image,
    mimeType: 'image/tiff',
    aliases: <String>['tif'],
    isLossless: true,
    description: 'Print and archival, multi-page.',
  );
  static const FileFormat ico = FileFormat(
    id: 'ico',
    label: 'ICO',
    mediaType: MediaType.image,
    mimeType: 'image/x-icon',
    description: 'Windows icon, small sizes only.',
  );
  static const FileFormat avif = FileFormat(
    id: 'avif',
    label: 'AVIF',
    mediaType: MediaType.image,
    mimeType: 'image/avif',
    description: 'AV1-based, very small files.',
  );
  static const FileFormat heic = FileFormat(
    id: 'heic',
    label: 'HEIC',
    mediaType: MediaType.image,
    mimeType: 'image/heic',
    aliases: <String>['heif'],
    canWrite: false,
    description: 'Apple photo format. Read only.',
  );
  static const FileFormat svg = FileFormat(
    id: 'svg',
    label: 'SVG',
    mediaType: MediaType.image,
    mimeType: 'image/svg+xml',
    canWrite: false,
    description: 'Vector source. Rasterised on output.',
  );

  // ---------------------------------------------------------------------------
  // Document
  // ---------------------------------------------------------------------------
  static const FileFormat pdf = FileFormat(
    id: 'pdf',
    label: 'PDF',
    mediaType: MediaType.document,
    mimeType: 'application/pdf',
    description: 'Fixed layout, universal.',
  );
  static const FileFormat doc = FileFormat(
    id: 'doc',
    label: 'DOC',
    mediaType: MediaType.document,
    mimeType: 'application/msword',
    canWrite: false,
    description: 'Legacy Word document. Read only.',
  );
  static const FileFormat docx = FileFormat(
    id: 'docx',
    label: 'DOCX',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    description: 'Word document.',
  );
  static const FileFormat odt = FileFormat(
    id: 'odt',
    label: 'ODT',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.oasis.opendocument.text',
    description: 'OpenDocument text.',
  );
  static const FileFormat rtf = FileFormat(
    id: 'rtf',
    label: 'RTF',
    mediaType: MediaType.document,
    mimeType: 'application/rtf',
    description: 'Rich Text Format.',
  );
  static const FileFormat txt = FileFormat(
    id: 'txt',
    label: 'TXT',
    mediaType: MediaType.document,
    mimeType: 'text/plain',
    description: 'Plain text.',
  );
  static const FileFormat md = FileFormat(
    id: 'md',
    label: 'Markdown',
    mediaType: MediaType.document,
    mimeType: 'text/markdown',
    aliases: <String>['markdown'],
    description: 'Markdown source.',
  );
  static const FileFormat html = FileFormat(
    id: 'html',
    label: 'HTML',
    mediaType: MediaType.document,
    mimeType: 'text/html',
    aliases: <String>['htm'],
    description: 'Web page.',
  );
  static const FileFormat ppt = FileFormat(
    id: 'ppt',
    label: 'PPT',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.ms-powerpoint',
    canWrite: false,
    description: 'Legacy PowerPoint. Read only.',
  );
  static const FileFormat pptx = FileFormat(
    id: 'pptx',
    label: 'PPTX',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    description: 'PowerPoint presentation.',
  );
  static const FileFormat odp = FileFormat(
    id: 'odp',
    label: 'ODP',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.oasis.opendocument.presentation',
    description: 'OpenDocument presentation.',
  );
  static const FileFormat xls = FileFormat(
    id: 'xls',
    label: 'XLS',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.ms-excel',
    canWrite: false,
    description: 'Legacy Excel workbook. Read only.',
  );
  static const FileFormat xlsx = FileFormat(
    id: 'xlsx',
    label: 'XLSX',
    mediaType: MediaType.document,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    description: 'Excel workbook.',
  );
  static const FileFormat ods = FileFormat(
    id: 'ods',
    label: 'ODS',
    mediaType: MediaType.document,
    mimeType: 'application/vnd.oasis.opendocument.spreadsheet',
    description: 'OpenDocument spreadsheet.',
  );
  static const FileFormat csv = FileFormat(
    id: 'csv',
    label: 'CSV',
    mediaType: MediaType.document,
    mimeType: 'text/csv',
    description: 'Comma-separated values.',
  );
  static const FileFormat epub = FileFormat(
    id: 'epub',
    label: 'EPUB',
    mediaType: MediaType.document,
    mimeType: 'application/epub+zip',
    description: 'E-book.',
  );

  // ---------------------------------------------------------------------------
  // Registry
  // ---------------------------------------------------------------------------
  static const List<FileFormat> videoFormats = <FileFormat>[
    mp4,
    mkv,
    mov,
    webm,
    avi,
    flv,
    wmv,
    threeGp,
    mpeg,
    m4v,
    ts,
    ogv,
  ];

  static const List<FileFormat> audioFormats = <FileFormat>[
    mp3,
    wav,
    flac,
    aac,
    m4a,
    ogg,
    opus,
    aiff,
    wma,
  ];

  static const List<FileFormat> imageFormats = <FileFormat>[
    png,
    jpg,
    webpFormat,
    gif,
    bmp,
    tiff,
    ico,
    avif,
    heic,
    svg,
  ];

  static const List<FileFormat> documentFormats = <FileFormat>[
    pdf,
    docx,
    doc,
    odt,
    rtf,
    txt,
    md,
    html,
    pptx,
    ppt,
    odp,
    xlsx,
    xls,
    ods,
    csv,
    epub,
  ];

  static const List<FileFormat> all = <FileFormat>[
    ...videoFormats,
    ...audioFormats,
    ...imageFormats,
    ...documentFormats,
  ];

  static List<FileFormat> byMediaType(MediaType type) => switch (type) {
    MediaType.video => videoFormats,
    MediaType.audio => audioFormats,
    MediaType.image => imageFormats,
    MediaType.document => documentFormats,
    MediaType.unknown => const <FileFormat>[],
  };

  /// Extension (lowercase, no dot) -> format, including aliases.
  static final Map<String, FileFormat> _byExtension = <String, FileFormat>{
    for (final FileFormat f in all)
      for (final String ext in f.allExtensions) ext: f,
  };

  static final Map<String, FileFormat> _byId = <String, FileFormat>{
    for (final FileFormat f in all) f.id: f,
  };

  /// Resolves a format from a filename extension. Returns null when unknown.
  static FileFormat? fromExtension(String extension) {
    final String key = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return _byExtension[key];
  }

  static FileFormat? fromId(String? id) => id == null ? null : _byId[id];

  /// Every extension the file picker should accept.
  static List<String> get allExtensions =>
      _byExtension.keys.where((String e) => _byExtension[e]!.canRead).toList()
        ..sort();

  static List<String> extensionsFor(MediaType type) =>
      _byExtension.entries
          .where((e) => e.value.mediaType == type && e.value.canRead)
          .map((e) => e.key)
          .toList()
        ..sort();

  // ---------------------------------------------------------------------------
  // Conversion matrix
  // ---------------------------------------------------------------------------

  /// Frame/still targets available when exporting from a video.
  static const List<FileFormat> _videoStillTargets = <FileFormat>[
    png,
    jpg,
    webpFormat,
    gif,
  ];

  /// Raster targets available when rendering a document page.
  static const List<FileFormat> _documentRasterTargets = <FileFormat>[
    png,
    jpg,
    tiff,
    webpFormat,
  ];

  /// Per-document-format output table.
  ///
  /// Document conversion is not a uniform matrix the way media transcoding is,
  /// so each source format declares its realistic targets explicitly.
  static final Map<String, List<FileFormat>> _documentTargets =
      <String, List<FileFormat>>{
        pdf.id: <FileFormat>[..._documentRasterTargets, txt, html],
        doc.id: <FileFormat>[pdf, docx, odt, rtf, txt, html],
        docx.id: <FileFormat>[pdf, odt, rtf, txt, html, md],
        odt.id: <FileFormat>[pdf, docx, rtf, txt, html, md],
        rtf.id: <FileFormat>[pdf, docx, odt, txt, html],
        txt.id: <FileFormat>[pdf, docx, odt, rtf, html, md],
        md.id: <FileFormat>[pdf, html, docx, odt, txt],
        html.id: <FileFormat>[pdf, docx, odt, txt, md],
        ppt.id: <FileFormat>[pdf, pptx, odp, png, jpg],
        pptx.id: <FileFormat>[pdf, odp, png, jpg],
        odp.id: <FileFormat>[pdf, pptx, png, jpg],
        xls.id: <FileFormat>[pdf, xlsx, ods, csv, html],
        xlsx.id: <FileFormat>[pdf, ods, csv, html],
        ods.id: <FileFormat>[pdf, xlsx, csv, html],
        csv.id: <FileFormat>[xlsx, ods, pdf, html, txt],
        epub.id: <FileFormat>[pdf, txt, html],
      };

  /// The output formats offered for a given input format.
  ///
  /// This is the exact question the FFI layer will answer later
  /// (`engine_supported_outputs(input_format)`), so the UI is already written
  /// against the final shape.
  static List<FileFormat> outputsFor(FileFormat input) {
    final List<FileFormat> result = switch (input.mediaType) {
      // Video can be transcoded, stripped to audio, or exported as stills.
      MediaType.video => <FileFormat>[
        ...videoFormats.where((FileFormat f) => f.canWrite),
        ...audioFormats.where((FileFormat f) => f.canWrite),
        ..._videoStillTargets,
      ],
      MediaType.audio =>
        audioFormats.where((FileFormat f) => f.canWrite).toList(),
      MediaType.image => <FileFormat>[
        ...imageFormats.where((FileFormat f) => f.canWrite),
        pdf,
      ],
      MediaType.document =>
        _documentTargets[input.id] ?? const <FileFormat>[pdf],
      MediaType.unknown => const <FileFormat>[],
    };

    // Never offer a no-op conversion.
    return result.where((FileFormat f) => f.id != input.id).toList();
  }

  /// True when the pair is a conversion the application offers.
  static bool isSupportedPair(FileFormat input, FileFormat output) =>
      outputsFor(input).contains(output);

  /// The output format pre-selected for a freshly added file.
  static FileFormat defaultOutputFor(FileFormat input) {
    final List<FileFormat> options = outputsFor(input);
    if (options.isEmpty) return input;

    final FileFormat preferred = switch (input.mediaType) {
      MediaType.video => mp4,
      MediaType.audio => mp3,
      MediaType.image => png,
      MediaType.document => pdf,
      MediaType.unknown => options.first,
    };

    if (options.contains(preferred)) return preferred;
    return options.first;
  }

  /// Groups a format list by media type, preserving the catalogue order.
  ///
  /// Used by the output-format picker so a video file can offer "Video",
  /// "Audio" and "Image" groups in one menu.
  static Map<MediaType, List<FileFormat>> groupByMediaType(
    List<FileFormat> formats,
  ) {
    final Map<MediaType, List<FileFormat>> grouped =
        <MediaType, List<FileFormat>>{};
    for (final FileFormat f in formats) {
      grouped.putIfAbsent(f.mediaType, () => <FileFormat>[]).add(f);
    }
    return grouped;
  }
}
