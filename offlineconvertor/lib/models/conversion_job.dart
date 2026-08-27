import '../core/utils/path_utils.dart';
import 'conversion_error.dart';
import 'conversion_request.dart';
import 'conversion_settings.dart';
import 'file_format.dart';
import 'file_info.dart';
import 'job_progress_update.dart';
import 'job_status.dart';
import 'media_type.dart';

/// One tracked conversion.
///
/// Immutable: state transitions produce a new instance via [copyWith] or
/// [applyUpdate]. That makes the provider's change notifications trivially
/// correct and means a job can never be observed half-updated.
class ConversionJob {
  const ConversionJob({
    required this.id,
    required this.request,
    required this.createdAt,
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.stage,
    this.eta,
    this.speedMultiplier,
    this.outputSizeBytes,
    this.error,
    this.startedAt,
    this.finishedAt,
    this.attempt = 1,
  });

  final String id;
  final ConversionRequest request;
  final DateTime createdAt;

  final JobStatus status;
  final double progress;
  final String? stage;
  final Duration? eta;
  final double? speedMultiplier;
  final int? outputSizeBytes;
  final ConversionError? error;

  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// 1 on first run, incremented by each retry.
  final int attempt;

  // --- Convenience accessors onto the request ---
  FileInfo get input => request.input;
  String get inputPath => request.input.path;
  String get outputPath => request.outputPath;
  String get fileName => request.input.name;
  String get outputFileName => PathUtils.fileName(request.outputPath);
  String get outputDirectory => PathUtils.directory(request.outputPath);
  FileFormat? get inputFormat => request.inputFormat;
  FileFormat get outputFormat => request.outputFormat;
  MediaType get mediaType => request.inputMediaType;
  ConversionType get conversionType => request.conversionType;
  ConversionSettings get settings => request.settings;
  int get inputSizeBytes => request.input.sizeBytes;

  /// "MP4 -> MP3"
  String get conversionLabel =>
      '${inputFormat?.badge ?? '?'} → ${outputFormat.badge}';

  bool get isTerminal => status.isTerminal;
  bool get isRunning => status.isActive;
  bool get isRetry => attempt > 1;

  /// Wall-clock time spent converting, or spent so far if still running.
  Duration? get elapsed {
    if (startedAt == null) return null;
    return (finishedAt ?? DateTime.now()).difference(startedAt!);
  }

  /// Output size relative to input, e.g. -42% for a smaller file.
  double? get sizeDeltaFraction {
    if (outputSizeBytes == null || inputSizeBytes <= 0) return null;
    return (outputSizeBytes! - inputSizeBytes) / inputSizeBytes;
  }

  ConversionJob copyWith({
    ConversionRequest? request,
    JobStatus? status,
    double? progress,
    String? stage,
    bool clearStage = false,
    Duration? eta,
    bool clearEta = false,
    double? speedMultiplier,
    bool clearSpeed = false,
    int? outputSizeBytes,
    ConversionError? error,
    bool clearError = false,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? attempt,
  }) {
    return ConversionJob(
      id: id,
      request: request ?? this.request,
      createdAt: createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      stage: clearStage ? null : (stage ?? this.stage),
      eta: clearEta ? null : (eta ?? this.eta),
      speedMultiplier: clearSpeed
          ? null
          : (speedMultiplier ?? this.speedMultiplier),
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      error: clearError ? null : (error ?? this.error),
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      attempt: attempt ?? this.attempt,
    );
  }

  /// Folds an engine status report into this job.
  ///
  /// Timestamps are managed here rather than by the engine so the UI always has
  /// consistent local clock values.
  ConversionJob applyUpdate(JobProgressUpdate update) {
    final bool nowStarting =
        startedAt == null && update.status == JobStatus.running;
    final bool nowFinishing = update.status.isTerminal;

    return copyWith(
      status: update.status,
      progress: update.status == JobStatus.completed ? 1.0 : update.progress,
      stage: update.stage,
      clearStage: update.stage == null && nowFinishing,
      eta: update.eta,
      clearEta: nowFinishing,
      speedMultiplier: update.speedMultiplier,
      clearSpeed: nowFinishing,
      outputSizeBytes: update.outputSizeBytes,
      error: update.error,
      clearError: update.status != JobStatus.failed,
      startedAt: nowStarting ? DateTime.now() : startedAt,
      finishedAt: nowFinishing ? DateTime.now() : null,
      clearFinishedAt: !nowFinishing,
    );
  }

  /// Resets the job to a fresh queued state, keeping its identity and history.
  ConversionJob asRetry({ConversionRequest? newRequest}) {
    return ConversionJob(
      id: id,
      request: newRequest ?? request,
      createdAt: createdAt,
      status: JobStatus.queued,
      progress: 0.0,
      attempt: attempt + 1,
    );
  }
}
