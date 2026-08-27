import 'conversion_error.dart';
import 'job_status.dart';

/// An incremental status report for a running job.
///
/// This is intentionally small and self-contained: it is the exact payload the
/// C++ engine will hand back from `engine_get_job_status(job_id)` (or push
/// through a progress callback). The Dart side already owns the
/// [ConversionRequest], so the engine never has to send it back.
class JobProgressUpdate {
  const JobProgressUpdate({
    required this.jobId,
    required this.status,
    required this.progress,
    this.stage,
    this.eta,
    this.speedMultiplier,
    this.outputSizeBytes,
    this.error,
  });

  final String jobId;
  final JobStatus status;

  /// 0.0 - 1.0.
  final double progress;

  /// Human label for the current phase, e.g. "Transcoding video".
  final String? stage;

  /// Estimated time remaining, when the engine can compute one.
  final Duration? eta;

  /// Conversion speed relative to real time (FFmpeg's `speed=` field).
  final double? speedMultiplier;

  /// Size of the produced file; only set once completed.
  final int? outputSizeBytes;

  /// Only set when [status] is [JobStatus.failed].
  final ConversionError? error;

  @override
  String toString() =>
      'JobProgressUpdate($jobId, ${status.name}, ${(progress * 100).toStringAsFixed(0)}%)';
}
