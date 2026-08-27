import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/constants/format_catalog.dart';
import '../core/utils/path_utils.dart';
import '../models/conversion_error.dart';
import '../models/conversion_request.dart';
import '../models/file_format.dart';
import '../models/file_info.dart';
import '../models/job_progress_update.dart';
import '../models/job_status.dart';
import '../models/media_type.dart';
import 'conversion_service.dart';

/// Stage 1 stand-in for the native engine.
///
/// It performs no real conversion. What it *does* faithfully reproduce is the
/// engine's observable behaviour, because that is what the UI is written
/// against:
///
///  * jobs are queued and only [maxConcurrentJobs] run at once;
///  * progress arrives incrementally with a stage label, speed and ETA;
///  * cancellation interrupts a running job promptly;
///  * failures arrive as a failed status with a typed [ConversionError], not as
///    a thrown exception;
///  * job state is owned here and read back through [statusOf].
///
/// Deterministic test hooks: a filename containing `fail` always fails, and one
/// containing `slow` takes much longer. Everything else is seeded from the job
/// id so a given job behaves consistently across its lifetime.
class MockConversionService implements ConversionService {
  MockConversionService({this.timeScale = 1.0});

  /// Multiplier on all simulated durations. Lower values make manual testing
  /// faster; tests can set it very low to keep runs quick.
  final double timeScale;

  static const Uuid _uuid = Uuid();
  static const Duration _tick = Duration(milliseconds: 120);

  final StreamController<JobProgressUpdate> _updates =
      StreamController<JobProgressUpdate>.broadcast();

  final Map<String, _MockJob> _jobs = <String, _MockJob>{};

  /// Job ids that have been started but are waiting for a free worker.
  final Queue<String> _pending = Queue<String>();

  int _maxConcurrent = 2;
  int _running = 0;
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize({int maxConcurrentJobs = 2}) async {
    if (_initialized) return;
    // Simulates the engine's start-up cost (loading libraries, probing tools).
    await Future<void>.delayed(_scaled(const Duration(milliseconds: 250)));
    _maxConcurrent = maxConcurrentJobs.clamp(1, 16);
    _initialized = true;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  EngineInfo get engineInfo => const EngineInfo(
    name: 'Simulated engine',
    version: 'stage-1',
    isNative: false,
    backends: <String, String>{
      'FFmpeg': 'not linked yet',
      'Image engine': 'not linked yet',
      'Document engine': 'not linked yet',
    },
  );

  @override
  Stream<JobProgressUpdate> get updates => _updates.stream;

  @override
  Future<void> setMaxConcurrentJobs(int value) async {
    _maxConcurrent = value.clamp(1, 16);
    _pump();
  }

  @override
  Future<void> shutdown() async {
    for (final _MockJob job in _jobs.values) {
      job.cancelled = true;
      job.ticker?.cancel();
    }
    _jobs.clear();
    _pending.clear();
    _running = 0;
    _initialized = false;
    await _updates.close();
  }

  // ---------------------------------------------------------------------------
  // Job management
  // ---------------------------------------------------------------------------

  @override
  Future<String> createJob(ConversionRequest request) async {
    _requireInitialized();
    final String id = _uuid.v4();
    _jobs[id] = _MockJob(id: id, request: request);
    _emit(id, JobStatus.queued, 0.0);
    return id;
  }

  @override
  Future<void> startJob(String jobId) async {
    _requireInitialized();
    final _MockJob? job = _jobs[jobId];
    if (job == null) {
      throw ConversionServiceException('Unknown job id: $jobId');
    }
    if (job.status != JobStatus.queued) return;
    if (job.enqueued) return;

    job.enqueued = true;
    job.cancelled = false;
    _pending.add(jobId);
    _pump();
  }

  @override
  Future<void> cancelJob(String jobId) async {
    final _MockJob? job = _jobs[jobId];
    if (job == null) return;
    if (job.status.isTerminal) return;

    job.cancelled = true;
    job.enqueued = false;
    _pending.remove(jobId);

    if (job.status == JobStatus.running) {
      // The ticker observes the flag and finishes the job, mirroring how the
      // engine will signal a running FFmpeg process and wait for it to exit.
      return;
    }
    _finish(job, JobStatus.cancelled);
  }

  @override
  Future<void> disposeJob(String jobId) async {
    final _MockJob? job = _jobs[jobId];
    if (job == null) return;
    job.cancelled = true;
    job.ticker?.cancel();
    if (job.status == JobStatus.running) _releaseSlot();
    _pending.remove(jobId);
    _jobs.remove(jobId);
  }

  @override
  JobProgressUpdate? statusOf(String jobId) {
    final _MockJob? job = _jobs[jobId];
    if (job == null) return null;
    return job.snapshot();
  }

  // ---------------------------------------------------------------------------
  // Probing
  // ---------------------------------------------------------------------------

  @override
  Future<FileInfo> probe(String path) async {
    final FileFormat? format = FormatCatalog.fromExtension(
      PathUtils.extension(path),
    );

    int size = 0;
    bool missing = false;
    try {
      final File file = File(path);
      if (await file.exists()) {
        size = await file.length();
      } else {
        missing = true;
      }
    } on FileSystemException {
      missing = true;
    }

    // Stage 2 replaces this block with the engine's real container probe.
    final Random rng = Random(path.hashCode);
    Duration? duration;
    int? width;
    int? height;
    int? pageCount;
    String? videoCodec;
    String? audioCodec;
    double? frameRate;

    switch (format?.mediaType) {
      case MediaType.video:
        duration = Duration(seconds: 20 + rng.nextInt(600));
        const List<List<int>> sizes = <List<int>>[
          <int>[1920, 1080],
          <int>[1280, 720],
          <int>[3840, 2160],
          <int>[854, 480],
        ];
        final List<int> dims = sizes[rng.nextInt(sizes.length)];
        width = dims[0];
        height = dims[1];
        videoCodec = const <String>['h264', 'h265', 'vp9'][rng.nextInt(3)];
        audioCodec = const <String>['aac', 'mp3', 'opus'][rng.nextInt(3)];
        frameRate = const <double>[24, 25, 30, 60][rng.nextInt(4)];
      case MediaType.audio:
        duration = Duration(seconds: 60 + rng.nextInt(300));
        audioCodec = const <String>['aac', 'mp3', 'flac'][rng.nextInt(3)];
      case MediaType.image:
        const List<List<int>> sizes = <List<int>>[
          <int>[4032, 3024],
          <int>[1920, 1080],
          <int>[800, 600],
          <int>[2560, 1440],
        ];
        final List<int> dims = sizes[rng.nextInt(sizes.length)];
        width = dims[0];
        height = dims[1];
      case MediaType.document:
        pageCount = 1 + rng.nextInt(40);
      case MediaType.unknown:
      case null:
        break;
    }

    return FileInfo(
      path: path,
      sizeBytes: size,
      format: format,
      duration: duration,
      width: width,
      height: height,
      pageCount: pageCount,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      frameRate: frameRate,
      probeFailed: missing,
    );
  }

  @override
  Future<List<FileFormat>> supportedOutputs(FileFormat input) async =>
      FormatCatalog.outputsFor(input);

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Starts as many pending jobs as the concurrency limit allows.
  void _pump() {
    while (_running < _maxConcurrent && _pending.isNotEmpty) {
      final String id = _pending.removeFirst();
      final _MockJob? job = _jobs[id];
      if (job == null || job.cancelled || job.status.isTerminal) continue;
      _running++;
      _run(job);
    }
  }

  void _releaseSlot() {
    if (_running > 0) _running--;
    // Deferred so a terminal update is delivered before the next job starts.
    scheduleMicrotask(_pump);
  }

  void _run(_MockJob job) {
    final _Plan plan = _planFor(job.request);

    job.status = JobStatus.running;
    job.enqueued = false;
    job.progress = 0.0;
    job.stage = plan.stages.first.label;
    job.startedAt = DateTime.now();
    job.plan = plan;
    _emit(job.id, JobStatus.running, 0.0, stage: job.stage);

    final Duration total = _scaled(plan.duration);

    // Elapsed time is accumulated from the ticks themselves rather than read
    // from a wall clock. That keeps the simulation driven entirely by the timer,
    // so it behaves identically under a test's virtual clock.
    Duration elapsed = Duration.zero;

    job.ticker = Timer.periodic(_tick, (Timer timer) {
      if (job.cancelled) {
        timer.cancel();
        _finish(job, JobStatus.cancelled);
        return;
      }

      elapsed += _tick;
      final double raw = total.inMicroseconds == 0
          ? 1.0
          : elapsed.inMicroseconds / total.inMicroseconds;
      final double fraction = raw.clamp(0.0, 1.0);

      // Simulated failures surface part-way through, the way a real encoder
      // error would, rather than immediately.
      if (plan.failure != null && fraction >= plan.failureAt) {
        timer.cancel();
        _finish(job, JobStatus.failed, error: plan.failure);
        return;
      }

      if (fraction >= 1.0) {
        timer.cancel();
        job.progress = 1.0;
        // The placeholder file is written before the job is reported complete,
        // so anything downstream (opening it, saving it) finds a real file.
        unawaited(_completeWithOutput(job, plan));
        return;
      }

      job.progress = fraction;
      job.stage = plan.stageAt(fraction);
      final Duration remaining = Duration(
        microseconds:
            ((total.inMicroseconds - elapsed.inMicroseconds) / timeScale)
                .round()
                .clamp(0, 1 << 40),
      );
      job.eta = remaining;
      job.speed = plan.speedMultiplier;

      _emit(
        job.id,
        JobStatus.running,
        fraction,
        stage: job.stage,
        eta: remaining,
        speed: plan.speedMultiplier,
      );
    });
  }

  /// Produces the output file, then marks the job complete.
  ///
  /// Stage 1 performs no real conversion, so the file is a clearly-labelled
  /// placeholder. Writing something real matters because it keeps the rest of
  /// the flow honest: the size shown is the file's actual size, and saving it
  /// exercises the same code path the native engine's output will.
  Future<void> _completeWithOutput(_MockJob job, _Plan plan) async {
    int size = plan.outputSizeBytes;
    try {
      final File output = File(job.request.outputPath);
      await output.parent.create(recursive: true);
      await output.writeAsString(_placeholderContent(job.request));
      size = await output.length();
    } on FileSystemException catch (e) {
      _finish(
        job,
        JobStatus.failed,
        error: ConversionError(
          code: ConversionErrorCode.outputNotWritable,
          message: 'Could not write the output file.',
          details: e.message,
        ),
      );
      return;
    }
    if (job.cancelled) {
      _finish(job, JobStatus.cancelled);
      return;
    }
    _finish(job, JobStatus.completed, outputSize: size);
  }

  static String _placeholderContent(ConversionRequest request) {
    return 'Convertor placeholder output\n'
        '\n'
        'This file was produced by the Stage 1 simulated engine, which does not\n'
        'perform real conversion. It stands in for:\n'
        '\n'
        '  source : ${request.input.name}\n'
        '  target : ${request.outputFormat.badge}\n'
        '  type   : ${request.conversionType.label}\n'
        '\n'
        'Connecting the native engine replaces this with the real output.\n';
  }

  void _finish(
    _MockJob job,
    JobStatus status, {
    ConversionError? error,
    int? outputSize,
  }) {
    job.ticker?.cancel();
    job.ticker = null;

    final bool wasRunning = job.status == JobStatus.running;
    job.status = status;
    job.stage = null;
    job.eta = null;
    job.speed = null;
    job.error = error;
    if (status == JobStatus.completed) {
      job.progress = 1.0;
      job.outputSizeBytes = outputSize;
    }

    _emit(
      job.id,
      status,
      job.progress,
      error: error,
      outputSize: job.outputSizeBytes,
    );

    if (wasRunning) _releaseSlot();
  }

  void _emit(
    String jobId,
    JobStatus status,
    double progress, {
    String? stage,
    Duration? eta,
    double? speed,
    int? outputSize,
    ConversionError? error,
  }) {
    if (_updates.isClosed) return;
    _updates.add(
      JobProgressUpdate(
        jobId: jobId,
        status: status,
        progress: progress,
        stage: stage,
        eta: eta,
        speedMultiplier: speed,
        outputSizeBytes: outputSize,
        error: error,
      ),
    );
  }

  Duration _scaled(Duration d) =>
      Duration(microseconds: (d.inMicroseconds * timeScale).round());

  void _requireInitialized() {
    if (!_initialized) {
      throw const ConversionServiceException(
        'Engine used before initialize() completed',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Simulation planning
  // ---------------------------------------------------------------------------

  /// Decides how long a job takes, what stages it reports, and whether it fails.
  _Plan _planFor(ConversionRequest request) {
    final String name = request.input.name.toLowerCase();
    final Random rng = Random(
      request.input.path.hashCode ^ request.outputFormat.id.hashCode,
    );

    // --- Deterministic pre-flight failures -----------------------------------
    if (request.input.probeFailed) {
      return _Plan.immediateFailure(
        const ConversionError(
          code: ConversionErrorCode.inputNotFound,
          message: 'The source file no longer exists at that path.',
        ),
      );
    }
    if (!request.conversionType.isSupported) {
      return _Plan.immediateFailure(
        ConversionError(
          code: ConversionErrorCode.unsupportedConversion,
          message:
              'Converting ${request.inputFormat?.badge ?? '?'} to '
              '${request.outputFormat.badge} is not supported.',
        ),
      );
    }

    // --- Duration -------------------------------------------------------------
    final double sizeMb = request.input.sizeBytes / (1024 * 1024);
    final double perTypeBase = switch (request.conversionType) {
      ConversionType.videoToVideo => 6.0,
      ConversionType.videoToAudio => 3.0,
      ConversionType.videoToImage => 2.0,
      ConversionType.audioToAudio => 2.5,
      ConversionType.imageToImage => 1.2,
      ConversionType.imageToDocument => 1.6,
      ConversionType.documentToDocument => 3.0,
      ConversionType.documentToImage => 3.5,
      ConversionType.unsupported => 1.0,
    };

    // A stream copy is dramatically faster than a re-encode; the mock reflects
    // that so the UI's speed/ETA display gets exercised realistically.
    final bool streamCopy =
        request.conversionType == ConversionType.videoToVideo &&
        request.settings.video.copyStreamsWhenPossible;

    double seconds = perTypeBase + min(sizeMb * 0.04, 8.0);
    if (streamCopy) seconds *= 0.35;
    if (name.contains('slow')) seconds *= 4;
    seconds *= 0.85 + rng.nextDouble() * 0.4;

    final Duration duration = Duration(
      milliseconds: (seconds * 1000).round().clamp(600, 60000),
    );

    // --- Failure injection ----------------------------------------------------
    ConversionError? failure;
    double failureAt = 1.1;
    if (name.contains('fail')) {
      failure = const ConversionError(
        code: ConversionErrorCode.encoderFailure,
        message: 'The encoder reported a fatal error while writing the output.',
        details:
            '[libx264 @ 0x55f1c0] error: unsupported pixel format\n'
            'Conversion failed!',
        exitCode: 1,
      );
      failureAt = 0.35;
    } else if (rng.nextDouble() < 0.07) {
      const List<ConversionError> candidates = <ConversionError>[
        ConversionError(
          code: ConversionErrorCode.corruptInput,
          message: 'The source file could not be decoded past this point.',
          details: 'Invalid data found when processing input',
          exitCode: 1,
        ),
        ConversionError(
          code: ConversionErrorCode.processFailure,
          message: 'The conversion process exited unexpectedly.',
          details: 'Process terminated with signal 11 (SIGSEGV)',
          exitCode: 139,
        ),
        ConversionError(
          code: ConversionErrorCode.insufficientDiskSpace,
          message: 'Ran out of space while writing the output file.',
          details: 'write() failed: No space left on device',
        ),
      ];
      failure = candidates[rng.nextInt(candidates.length)];
      failureAt = 0.2 + rng.nextDouble() * 0.6;
    }

    // --- Output size estimate -------------------------------------------------
    final int outputSize = _estimateOutputSize(request, rng);

    return _Plan(
      duration: duration,
      stages: _stagesFor(request.conversionType, streamCopy),
      speedMultiplier: streamCopy
          ? 20 + rng.nextDouble() * 30
          : 0.6 + rng.nextDouble() * 3.5,
      failure: failure,
      failureAt: failureAt,
      outputSizeBytes: outputSize,
    );
  }

  static List<_Stage> _stagesFor(ConversionType type, bool streamCopy) {
    if (streamCopy) {
      return const <_Stage>[
        _Stage(0.0, 'Reading container'),
        _Stage(0.15, 'Copying streams'),
        _Stage(0.9, 'Writing output'),
      ];
    }
    return switch (type) {
      ConversionType.videoToVideo => const <_Stage>[
        _Stage(0.0, 'Analysing input'),
        _Stage(0.08, 'Transcoding video'),
        _Stage(0.85, 'Muxing streams'),
        _Stage(0.96, 'Writing output'),
      ],
      ConversionType.videoToAudio => const <_Stage>[
        _Stage(0.0, 'Analysing input'),
        _Stage(0.1, 'Extracting audio'),
        _Stage(0.85, 'Encoding audio'),
        _Stage(0.97, 'Writing output'),
      ],
      ConversionType.videoToImage => const <_Stage>[
        _Stage(0.0, 'Seeking frames'),
        _Stage(0.2, 'Exporting frames'),
        _Stage(0.9, 'Writing output'),
      ],
      ConversionType.audioToAudio => const <_Stage>[
        _Stage(0.0, 'Decoding audio'),
        _Stage(0.15, 'Encoding audio'),
        _Stage(0.94, 'Writing tags'),
      ],
      ConversionType.imageToImage => const <_Stage>[
        _Stage(0.0, 'Decoding image'),
        _Stage(0.3, 'Resampling'),
        _Stage(0.7, 'Encoding image'),
      ],
      ConversionType.imageToDocument => const <_Stage>[
        _Stage(0.0, 'Decoding image'),
        _Stage(0.4, 'Composing page'),
        _Stage(0.8, 'Writing PDF'),
      ],
      ConversionType.documentToDocument => const <_Stage>[
        _Stage(0.0, 'Parsing document'),
        _Stage(0.25, 'Laying out content'),
        _Stage(0.8, 'Writing output'),
      ],
      ConversionType.documentToImage => const <_Stage>[
        _Stage(0.0, 'Parsing document'),
        _Stage(0.2, 'Rasterising pages'),
        _Stage(0.9, 'Writing images'),
      ],
      ConversionType.unsupported => const <_Stage>[_Stage(0.0, 'Working')],
    };
  }

  /// Rough output-size model so the completed state shows a believable
  /// size delta. Replaced by the real file size in Stage 2.
  static int _estimateOutputSize(ConversionRequest request, Random rng) {
    final int input = request.input.sizeBytes;
    if (input <= 0) return 0;

    double ratio = switch (request.conversionType) {
      ConversionType.videoToVideo =>
        request.settings.video.copyStreamsWhenPossible ? 1.0 : 0.55,
      ConversionType.videoToAudio => 0.08,
      ConversionType.videoToImage => 0.01,
      ConversionType.audioToAudio =>
        request.outputFormat.isLossless ? 4.5 : 0.35,
      ConversionType.imageToImage =>
        request.outputFormat.isLossless ? 2.2 : 0.45,
      ConversionType.imageToDocument => 1.1,
      ConversionType.documentToDocument => 0.9,
      ConversionType.documentToImage => 2.5,
      ConversionType.unsupported => 1.0,
    };

    // Quality/resolution choices move the estimate.
    if (request.outputMediaType == MediaType.video) {
      final int? h = request.settings.video.resolution.height;
      final int? sourceH = request.input.height;
      if (h != null && sourceH != null && sourceH > 0) {
        ratio *= (h / sourceH).clamp(0.1, 1.0);
      }
    }
    if (request.outputMediaType == MediaType.image &&
        !request.outputFormat.isLossless) {
      ratio *= request.settings.image.quality / 90;
    }

    ratio *= 0.9 + rng.nextDouble() * 0.2;
    return max(1024, (input * ratio).round());
  }
}

// -----------------------------------------------------------------------------
// Internal simulation types
// -----------------------------------------------------------------------------

class _Stage {
  const _Stage(this.from, this.label);
  final double from;
  final String label;
}

class _Plan {
  const _Plan({
    required this.duration,
    required this.stages,
    required this.speedMultiplier,
    required this.outputSizeBytes,
    this.failure,
    this.failureAt = 1.1,
  });

  factory _Plan.immediateFailure(ConversionError error) => _Plan(
    duration: const Duration(milliseconds: 700),
    stages: const <_Stage>[_Stage(0.0, 'Validating input')],
    speedMultiplier: 0,
    outputSizeBytes: 0,
    failure: error,
    failureAt: 0.05,
  );

  final Duration duration;
  final List<_Stage> stages;
  final double speedMultiplier;
  final int outputSizeBytes;
  final ConversionError? failure;
  final double failureAt;

  String stageAt(double fraction) {
    String label = stages.first.label;
    for (final _Stage s in stages) {
      if (fraction >= s.from) {
        label = s.label;
      } else {
        break;
      }
    }
    return label;
  }
}

class _MockJob {
  _MockJob({required this.id, required this.request});

  final String id;
  final ConversionRequest request;

  JobStatus status = JobStatus.queued;
  double progress = 0.0;
  String? stage;
  Duration? eta;
  double? speed;
  int? outputSizeBytes;
  ConversionError? error;
  DateTime? startedAt;

  bool cancelled = false;
  bool enqueued = false;
  Timer? ticker;
  _Plan? plan;

  JobProgressUpdate snapshot() => JobProgressUpdate(
    jobId: id,
    status: status,
    progress: progress,
    stage: stage,
    eta: eta,
    speedMultiplier: speed,
    outputSizeBytes: outputSizeBytes,
    error: error,
  );
}
