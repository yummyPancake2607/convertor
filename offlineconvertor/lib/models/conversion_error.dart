/// Machine-readable failure categories.
///
/// The C++ engine will return one of these codes alongside a human message.
/// Keeping the taxonomy in the model layer means the UI can react to a category
/// (offer "choose another folder" for [outputNotWritable]) rather than parsing
/// English text.
enum ConversionErrorCode {
  unsupportedFormat,
  unsupportedConversion,
  inputNotFound,
  inputNotReadable,
  corruptInput,
  outputNotWritable,
  outputExists,
  permissionDenied,
  insufficientDiskSpace,
  missingDependency,
  encoderFailure,
  processFailure,
  cancelled,
  timeout,
  unknown;

  String get label => switch (this) {
    ConversionErrorCode.unsupportedFormat => 'Unsupported format',
    ConversionErrorCode.unsupportedConversion => 'Unsupported conversion',
    ConversionErrorCode.inputNotFound => 'File not found',
    ConversionErrorCode.inputNotReadable => 'File not readable',
    ConversionErrorCode.corruptInput => 'Corrupt or invalid file',
    ConversionErrorCode.outputNotWritable => 'Cannot write output',
    ConversionErrorCode.outputExists => 'Output already exists',
    ConversionErrorCode.permissionDenied => 'Permission denied',
    ConversionErrorCode.insufficientDiskSpace => 'Not enough disk space',
    ConversionErrorCode.missingDependency => 'Missing dependency',
    ConversionErrorCode.encoderFailure => 'Encoder failed',
    ConversionErrorCode.processFailure => 'Conversion process failed',
    ConversionErrorCode.cancelled => 'Cancelled',
    ConversionErrorCode.timeout => 'Timed out',
    ConversionErrorCode.unknown => 'Conversion failed',
  };

  /// Whether retrying without changing anything could plausibly succeed.
  bool get isTransient => switch (this) {
    ConversionErrorCode.processFailure ||
    ConversionErrorCode.encoderFailure ||
    ConversionErrorCode.timeout ||
    ConversionErrorCode.unknown => true,
    _ => false,
  };

  /// What the user can do about it.
  String get remedy => switch (this) {
    ConversionErrorCode.unsupportedFormat =>
      'This format is not in the supported list.',
    ConversionErrorCode.unsupportedConversion =>
      'Pick a different output format.',
    ConversionErrorCode.inputNotFound =>
      'The source file was moved or deleted. Re-add it.',
    ConversionErrorCode.inputNotReadable ||
    ConversionErrorCode.permissionDenied =>
      'Check the file permissions and try again.',
    ConversionErrorCode.corruptInput => 'The source file could not be decoded.',
    ConversionErrorCode.outputNotWritable =>
      'Choose a different output folder.',
    ConversionErrorCode.outputExists =>
      'Enable overwrite in Settings, or rename the output.',
    ConversionErrorCode.insufficientDiskSpace =>
      'Free up disk space and retry.',
    ConversionErrorCode.missingDependency =>
      'A required conversion component is unavailable.',
    ConversionErrorCode.encoderFailure || ConversionErrorCode.processFailure =>
      'Retry, or try a different output format.',
    ConversionErrorCode.timeout => 'Retry the conversion.',
    ConversionErrorCode.cancelled => 'The job was cancelled.',
    ConversionErrorCode.unknown => 'Retry the conversion.',
  };

  String get id => name;

  static ConversionErrorCode fromId(String? id) =>
      ConversionErrorCode.values.firstWhere(
        (ConversionErrorCode c) => c.name == id,
        orElse: () => ConversionErrorCode.unknown,
      );
}

/// A conversion failure: category, user-facing message, and optional engine
/// diagnostics (FFmpeg stderr tail, exit code) for the details panel.
class ConversionError {
  const ConversionError({
    required this.code,
    required this.message,
    this.details,
    this.exitCode,
  });

  final ConversionErrorCode code;
  final String message;
  final String? details;
  final int? exitCode;

  bool get isRetryable => code.isTransient;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code.id,
    'message': message,
    'details': details,
    'exitCode': exitCode,
  };

  factory ConversionError.fromJson(Map<String, dynamic> json) =>
      ConversionError(
        code: ConversionErrorCode.fromId(json['code'] as String?),
        message: json['message'] as String? ?? 'Conversion failed',
        details: json['details'] as String?,
        exitCode: json['exitCode'] as int?,
      );

  @override
  String toString() => '${code.label}: $message';
}
