import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/format_catalog.dart';
import '../core/utils/path_utils.dart';
import '../models/conversion_error.dart';
import '../models/conversion_request.dart';
import '../models/file_format.dart';
import '../models/file_info.dart';
import '../models/job_progress_update.dart';
import '../models/job_status.dart';
import 'conversion_service.dart';

// FFI function signatures
typedef _EngineCreateNative = Uint64 Function();
typedef _EngineCreateDart = int Function();

typedef _EngineDestroyNative = Void Function(Uint64);
typedef _EngineDestroyDart = void Function(int handle);

typedef _ProbeNative = Uint64 Function(Uint64, Pointer<Utf8>);
typedef _ProbeDart = int Function(int engine, Pointer<Utf8> path);

typedef _ProbeDurationNative = Int64 Function(Uint64);
typedef _ProbeDurationDart = int Function(int handle);

typedef _ProbeWidthNative = Int32 Function(Uint64);
typedef _ProbeWidthDart = int Function(int handle);

typedef _ProbeHeightNative = Int32 Function(Uint64);
typedef _ProbeHeightDart = int Function(int handle);

typedef _ProbeFrameRateNative = Double Function(Uint64);
typedef _ProbeFrameRateDart = double Function(int handle);

typedef _ProbeVideoCodecNative = Pointer<Utf8> Function(Uint64);
typedef _ProbeVideoCodecDart = Pointer<Utf8> Function(int handle);

typedef _ProbeAudioCodecNative = Pointer<Utf8> Function(Uint64);
typedef _ProbeAudioCodecDart = Pointer<Utf8> Function(int handle);

typedef _ProbeDisposeNative = Void Function(Uint64);
typedef _ProbeDisposeDart = void Function(int handle);

typedef _ConvertNative = Uint64 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>);
typedef _ConvertDart = int Function(
    int engine, Pointer<Utf8> input, Pointer<Utf8> output);

typedef _JobStatusNative = Int32 Function(Uint64, Uint64);
typedef _JobStatusDart = int Function(int engine, int job);

typedef _JobProgressNative = Float Function(Uint64, Uint64);
typedef _JobProgressDart = double Function(int engine, int job);

typedef _JobStageNative = Pointer<Utf8> Function(Uint64, Uint64);
typedef _JobStageDart = Pointer<Utf8> Function(int engine, int job);

typedef _JobErrorNative = Pointer<Utf8> Function(Uint64, Uint64);
typedef _JobErrorDart = Pointer<Utf8> Function(int engine, int job);

typedef _JobCancelNative = Void Function(Uint64, Uint64);
typedef _JobCancelDart = void Function(int engine, int job);

typedef _SupportedOutputsNative = Pointer<Utf8> Function(Uint64, Pointer<Utf8>);
typedef _SupportedOutputsDart = Pointer<Utf8> Function(
    int engine, Pointer<Utf8> formatId);

typedef _EngineVersionNative = Pointer<Utf8> Function();
typedef _EngineVersionDart = Pointer<Utf8> Function();

/// Native FFI implementation of [ConversionService].
///
/// Loads the C++ engine shared library and calls its C API through dart:ffi.
class CppFfiConversionService implements ConversionService {
  static const String _libName = 'libconvertor.so';

  late final DynamicLibrary _lib;
  late final _EngineCreateDart _engineCreate;
  late final _EngineDestroyDart _engineDestroy;
  late final _ProbeDart _probe;
  late final _ProbeDurationDart _probeDuration;
  late final _ProbeWidthDart _probeWidth;
  late final _ProbeHeightDart _probeHeight;
  late final _ProbeFrameRateDart _probeFrameRate;
  late final _ProbeVideoCodecDart _probeVideoCodec;
  late final _ProbeAudioCodecDart _probeAudioCodec;
  late final _ProbeDisposeDart _probeDispose;
  late final _ConvertDart _convert;
  late final _JobStatusDart _jobStatus;
  late final _JobProgressDart _jobProgress;
  late final _JobStageDart _jobStage;
  late final _JobErrorDart _jobError;
  late final _JobCancelDart _jobCancel;
  late final _SupportedOutputsDart _supportedOutputs;
  late final _EngineVersionDart _engineVersion;

  int _engineHandle = 0;
  bool _initialized = false;

  final StreamController<JobProgressUpdate> _updates =
      StreamController<JobProgressUpdate>.broadcast();

  final Map<String, _NativeJob> _jobs = <String, _NativeJob>{};
  Timer? _pollTimer;

  CppFfiConversionService() {
    _lib = _loadLibrary();
    _bindFunctions();
  }

  DynamicLibrary _loadLibrary() {
    // Android packages the engine in the APK under jniLibs/<abi>/, where the
    // dynamic loader finds it by bare name. Nothing else is on the search path,
    // so there is no fallback to try.
    if (Platform.isAndroid) {
      debugPrint('[FFI] Loading native library: $_libName');
      return DynamicLibrary.open(_libName);
    }

    if (Platform.isLinux) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final paths = [
        '$exeDir/lib/$_libName',
        '${Directory.current.parent.path}/engine/build/$_libName',
        '${Directory.current.path}/engine/build/$_libName',
        '/home/snowowl/convertor/engine/build/$_libName',
        _libName,
      ];
      for (final path in paths) {
        try {
          if (File(path).existsSync()) {
            debugPrint('[FFI] Loading native library from: $path');
            return DynamicLibrary.open(path);
          }
        } catch (_) {}
      }
      debugPrint('[FFI] ERROR: Could not find $_libName in any path');
      throw StateError('Native library $_libName not found');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('convertor.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libconvertor.dylib');
    }
    throw UnsupportedError('Platform not supported');
  }

  void _bindFunctions() {
    _engineCreate = _lib
        .lookupFunction<_EngineCreateNative, _EngineCreateDart>(
            'convertor_engine_create');
    _engineDestroy = _lib
        .lookupFunction<_EngineDestroyNative, _EngineDestroyDart>(
            'convertor_engine_destroy');
    _probe = _lib.lookupFunction<_ProbeNative, _ProbeDart>('convertor_probe');
    _probeDuration = _lib.lookupFunction<_ProbeDurationNative,
        _ProbeDurationDart>('convertor_probe_duration_us');
    _probeWidth = _lib
        .lookupFunction<_ProbeWidthNative, _ProbeWidthDart>(
            'convertor_probe_width');
    _probeHeight = _lib
        .lookupFunction<_ProbeHeightNative, _ProbeHeightDart>(
            'convertor_probe_height');
    _probeFrameRate = _lib.lookupFunction<_ProbeFrameRateNative,
        _ProbeFrameRateDart>('convertor_probe_frame_rate');
    _probeVideoCodec = _lib.lookupFunction<_ProbeVideoCodecNative,
        _ProbeVideoCodecDart>('convertor_probe_video_codec');
    _probeAudioCodec = _lib.lookupFunction<_ProbeAudioCodecNative,
        _ProbeAudioCodecDart>('convertor_probe_audio_codec');
    _probeDispose = _lib
        .lookupFunction<_ProbeDisposeNative, _ProbeDisposeDart>(
            'convertor_probe_dispose');
    _convert = _lib.lookupFunction<_ConvertNative, _ConvertDart>(
        'convertor_convert');
    _jobStatus = _lib
        .lookupFunction<_JobStatusNative, _JobStatusDart>(
            'convertor_job_status');
    _jobProgress = _lib.lookupFunction<_JobProgressNative,
        _JobProgressDart>('convertor_job_progress');
    _jobStage = _lib
        .lookupFunction<_JobStageNative, _JobStageDart>(
            'convertor_job_stage');
    _jobError = _lib.lookupFunction<_JobErrorNative, _JobErrorDart>(
        'convertor_job_error');
    _jobCancel = _lib
        .lookupFunction<_JobCancelNative, _JobCancelDart>(
            'convertor_job_cancel');
    _supportedOutputs = _lib.lookupFunction<_SupportedOutputsNative,
        _SupportedOutputsDart>('convertor_supported_outputs');
    _engineVersion = _lib.lookupFunction<_EngineVersionNative,
        _EngineVersionDart>('convertor_engine_version');
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize({int maxConcurrentJobs = 2}) async {
    if (_initialized) return;
    _engineHandle = _engineCreate();
    debugPrint('[FFI] initialize: engineHandle=$_engineHandle');
    if (_engineHandle == 0) {
      throw const ConversionServiceException('Failed to create engine');
    }
    _initialized = true;
    _startPolling();
  }

  @override
  bool get isInitialized => _initialized;

  @override
  EngineInfo get engineInfo {
    final Pointer<Utf8> versionPtr = _engineVersion();
    final String version = versionPtr.toDartString();
    return EngineInfo(
      name: 'Convertor Native',
      version: version,
      isNative: true,
      backends: const <String, String>{
        'FFmpeg': 'linked',
      },
    );
  }

  @override
  Stream<JobProgressUpdate> get updates => _updates.stream;

  @override
  Future<void> setMaxConcurrentJobs(int value) async {
    // Not supported by the native engine yet
  }

  @override
  Future<void> shutdown() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final job in _jobs.values) {
      if (job.status != JobStatus.completed &&
          job.status != JobStatus.failed &&
          job.status != JobStatus.cancelled) {
        _jobCancel(_engineHandle, job.nativeHandle);
      }
    }
    _jobs.clear();
    if (_engineHandle != 0) {
      _engineDestroy(_engineHandle);
      _engineHandle = 0;
    }
    _initialized = false;
    if (!_updates.isClosed) await _updates.close();
  }

  // ---------------------------------------------------------------------------
  // Job management
  // ---------------------------------------------------------------------------

  @override
  Future<String> createJob(ConversionRequest request) async {
    _requireInitialized();

    final String id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final Pointer<Utf8> inputPtr = request.input.path.toNativeUtf8();
    final Pointer<Utf8> outputPtr = request.outputPath.toNativeUtf8();

    try {
      debugPrint('[FFI] createJob: input=${request.input.path} output=${request.outputPath}');
      final int nativeHandle = _convert(_engineHandle, inputPtr, outputPtr);
      debugPrint('[FFI] createJob: nativeHandle=$nativeHandle');
      if (nativeHandle == 0) {
        throw const ConversionServiceException('Failed to create job');
      }

      _jobs[id] = _NativeJob(
        nativeHandle: nativeHandle,
        request: request,
        status: JobStatus.running,
      );
      _emit(id, JobStatus.running, 0.0);
      return id;
    } finally {
      callocFree(inputPtr);
      callocFree(outputPtr);
    }
  }

  @override
  Future<void> startJob(String jobId) async {
    // Jobs are started immediately on creation in the native engine
  }

  @override
  Future<void> cancelJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return;
    if (job.status.isTerminal) return;

    _jobCancel(_engineHandle, job.nativeHandle);
    _updateJobFromNative(jobId, job);
  }

  @override
  Future<void> disposeJob(String jobId) async {
    _jobs.remove(jobId);
  }

  @override
  JobProgressUpdate? statusOf(String jobId) {
    final job = _jobs[jobId];
    if (job == null) return null;
    _updateJobFromNative(jobId, job);
    return JobProgressUpdate(
      jobId: jobId,
      status: job.status,
      progress: job.progress,
      stage: job.stage,
      error: job.error,
      outputSizeBytes: job.outputSizeBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Probing
  // ---------------------------------------------------------------------------

  @override
  Future<FileInfo> probe(String path) async {
    _requireInitialized();

    final Pointer<Utf8> pathPtr = path.toNativeUtf8();
    try {
      final int probeHandle = _probe(_engineHandle, pathPtr);
      if (probeHandle == 0) {
        // Probe failed, return basic info from extension
        return _probeFromExtension(path);
      }

      try {
        final int durationUs = _probeDuration(probeHandle);
        final int width = _probeWidth(probeHandle);
        final int height = _probeHeight(probeHandle);
        final double frameRate = _probeFrameRate(probeHandle);
        final String videoCodec = _probeVideoCodec(probeHandle).toDartString();
        final String audioCodec = _probeAudioCodec(probeHandle).toDartString();

        int size = 0;
        try {
          final file = File(path);
          if (await file.exists()) size = await file.length();
        } catch (_) {}

        final FileFormat? format =
            FormatCatalog.fromExtension(PathUtils.extension(path));

        final Duration? duration = durationUs > 0
            ? Duration(milliseconds: (durationUs / 1000).round())
            : null;

        return FileInfo(
          path: path,
          sizeBytes: size,
          format: format,
          duration: duration,
          width: width > 0 ? width : null,
          height: height > 0 ? height : null,
          videoCodec: videoCodec.isNotEmpty ? videoCodec : null,
          audioCodec: audioCodec.isNotEmpty ? audioCodec : null,
          frameRate: frameRate > 0 ? frameRate : null,
        );
      } finally {
        _probeDispose(probeHandle);
      }
    } finally {
      callocFree(pathPtr);
    }
  }

  FileInfo _probeFromExtension(String path) {
    final FileFormat? format =
        FormatCatalog.fromExtension(PathUtils.extension(path));
    int size = 0;
    try {
      final file = File(path);
      if (file.existsSync()) size = file.lengthSync();
    } catch (_) {}

    return FileInfo(
      path: path,
      sizeBytes: size,
      format: format,
      probeFailed: format == null,
    );
  }

  @override
  Future<List<FileFormat>> supportedOutputs(FileFormat input) async {
    _requireInitialized();

    final Pointer<Utf8> idPtr = input.id.toNativeUtf8();
    try {
      final Pointer<Utf8> resultPtr = _supportedOutputs(_engineHandle, idPtr);
      final String csv = resultPtr.toDartString();
      if (csv.isEmpty) return <FileFormat>[];

      return csv
          .split(',')
          .map((id) => FormatCatalog.fromId(id))
          .whereType<FileFormat>()
          .toList();
    } finally {
      callocFree(idPtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Polling
  // ---------------------------------------------------------------------------

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _pollJobs();
    });
  }

  void _pollJobs() {
    for (final entry in _jobs.entries.toList()) {
      final String id = entry.key;
      final _NativeJob job = entry.value;
      if (job.status.isTerminal) continue;

      _updateJobFromNative(id, job);
    }
  }

  void _updateJobFromNative(String id, _NativeJob job) {
    final int nativeStatus = _jobStatus(_engineHandle, job.nativeHandle);
    final double progress = _jobProgress(_engineHandle, job.nativeHandle);
    final Pointer<Utf8> stagePtr = _jobStage(_engineHandle, job.nativeHandle);
    final String stage = stagePtr.toDartString();
    final Pointer<Utf8> errorPtr = _jobError(_engineHandle, job.nativeHandle);
    final String errorStr = errorPtr.toDartString();

    final JobStatus newStatus = _mapStatus(nativeStatus);
    final bool changed = newStatus != job.status;
    final bool progressChanged = (progress - job.progress).abs() > 0.001;

    if (changed || progressChanged) {
      debugPrint('[FFI] Job $id (native=${job.nativeHandle}): status=$newStatus progress=${(progress * 100).toStringAsFixed(1)}% stage=$stage error=$errorStr');
    }

    job.status = newStatus;
    job.progress = progress;
    job.stage = stage.isNotEmpty ? stage : null;

    if (errorStr.isNotEmpty && newStatus == JobStatus.failed) {
      job.error = ConversionError(
        code: ConversionErrorCode.encoderFailure,
        message: errorStr,
      );
    }

    // The engine reports where it wrote, not how much; the results screen wants
    // a size, so read it off the finished file once.
    if (newStatus == JobStatus.completed && job.outputSizeBytes == null) {
      try {
        final File output = File(job.request.outputPath);
        if (output.existsSync()) job.outputSizeBytes = output.lengthSync();
      } catch (_) {
        // A missing or unreadable output only costs us the size label.
      }
    }

    if (changed || progressChanged) {
      _emit(id, newStatus, progress,
          stage: job.stage,
          error: job.error,
          outputSizeBytes: job.outputSizeBytes);
    }
  }

  JobStatus _mapStatus(int native) {
    switch (native) {
      case 0:
        return JobStatus.queued;
      case 1:
        return JobStatus.running;
      case 2:
        return JobStatus.completed;
      case 3:
        return JobStatus.failed;
      case 4:
        return JobStatus.cancelled;
      default:
        return JobStatus.running;
    }
  }

  void _emit(
    String jobId,
    JobStatus status,
    double progress, {
    String? stage,
    ConversionError? error,
    int? outputSizeBytes,
  }) {
    if (_updates.isClosed) return;
    _updates.add(JobProgressUpdate(
      jobId: jobId,
      status: status,
      progress: progress,
      stage: stage,
      error: error,
      outputSizeBytes: outputSizeBytes,
    ));
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw const ConversionServiceException(
        'Engine used before initialize() completed',
      );
    }
  }
}

class _NativeJob {
  _NativeJob({
    required this.nativeHandle,
    required this.request,
    required this.status,
  });

  final int nativeHandle;
  final ConversionRequest request;
  JobStatus status;
  double progress = 0.0;
  String? stage;
  ConversionError? error;
  int? outputSizeBytes;
}

// Helper to free native memory allocated by toNativeUtf8()
void callocFree(Pointer ptr) {
  calloc.free(ptr);
}
