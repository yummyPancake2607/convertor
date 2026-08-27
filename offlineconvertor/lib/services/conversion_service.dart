import 'dart:async';

import '../models/conversion_request.dart';
import '../models/file_format.dart';
import '../models/file_info.dart';
import '../models/job_progress_update.dart';

/// The boundary between the Flutter application and the conversion engine.
///
/// This interface is deliberately shaped like the C-compatible FFI surface that
/// the C++ engine will expose in Stage 2:
///
/// ```text
///   initialize()      -> engine_initialize()
///   createJob()       -> engine_create_job()      returns an opaque job id
///   startJob()        -> engine_start_job(id)
///   cancelJob()       -> engine_cancel_job(id)
///   disposeJob()      -> engine_destroy_job(id)
///   statusOf()        -> engine_get_job_status(id)
///   updates           <- progress callback / poll loop
///   shutdown()        -> engine_shutdown()
/// ```
///
/// Nothing above the service layer knows whether the work is mocked or native.
/// Swapping [MockConversionService] for a `CppFfiConversionService` must
/// therefore require no changes in the providers or the UI.
abstract interface class ConversionService {
  /// Starts the engine. Must be awaited before any other call.
  ///
  /// [maxConcurrentJobs] is the worker-thread limit the engine should honour.
  Future<void> initialize({int maxConcurrentJobs = 2});

  /// True once [initialize] has completed and [shutdown] has not been called.
  bool get isInitialized;

  /// Human-readable engine identification, shown in Settings.
  EngineInfo get engineInfo;

  /// Registers a conversion and returns its job id.
  ///
  /// Creating a job does not start it: the queue decides when to run.
  Future<String> createJob(ConversionRequest request);

  /// Moves a queued job into the engine's run queue.
  ///
  /// The engine still applies its own concurrency limit, so a started job may
  /// remain [JobStatus.queued] until a worker is free.
  Future<void> startJob(String jobId);

  /// Requests cancellation. Returns once the request has been delivered; the
  /// terminal [JobProgressUpdate] arrives on [updates].
  Future<void> cancelJob(String jobId);

  /// Releases engine-side resources for a job. Cancels it first if running.
  Future<void> disposeJob(String jobId);

  /// Current state of a job, or null when the engine does not know the id.
  JobProgressUpdate? statusOf(String jobId);

  /// A single stream of state changes for every job the engine owns.
  ///
  /// The provider layer folds these into its [ConversionJob] list. Broadcast, so
  /// more than one listener is allowed.
  Stream<JobProgressUpdate> get updates;

  /// Updates the engine's worker-thread limit at runtime.
  Future<void> setMaxConcurrentJobs(int value);

  /// Inspects a file and reports what the engine can determine about it.
  ///
  /// Stage 1 resolves this from the extension. Stage 2 will probe the actual
  /// container, which is why the return type is the richer [FileInfo] rather
  /// than a bare format.
  Future<FileInfo> probe(String path);

  /// Output formats the engine can produce from [input].
  Future<List<FileFormat>> supportedOutputs(FileFormat input);

  /// Stops workers and releases all engine resources.
  Future<void> shutdown();
}

/// Identification and capability report for the active engine.
class EngineInfo {
  const EngineInfo({
    required this.name,
    required this.version,
    required this.isNative,
    this.backends = const <String, String>{},
  });

  final String name;
  final String version;

  /// False for the Stage 1 mock, true for the native FFI engine.
  final bool isNative;

  /// Backend component -> version, e.g. `{'FFmpeg': '7.1'}`.
  final Map<String, String> backends;

  String get displayName => '$name $version';
}

/// Thrown for programming errors against the service contract (unknown job id,
/// use before initialisation). Conversion *failures* are not exceptions: they
/// arrive as a failed [JobProgressUpdate] carrying a `ConversionError`.
class ConversionServiceException implements Exception {
  const ConversionServiceException(this.message);

  final String message;

  @override
  String toString() => 'ConversionServiceException: $message';
}
