import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/models/conversion_request.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/file_info.dart';
import 'package:offlineconvertor/models/job_progress_update.dart';
import 'package:offlineconvertor/models/job_status.dart';
import 'package:offlineconvertor/services/conversion_service.dart';
import 'package:offlineconvertor/services/mock_conversion_service.dart';

/// Builds a request without touching the filesystem.
ConversionRequest request({
  String name = 'clip.mp4',
  FileFormat? input,
  FileFormat? output,
  int sizeBytes = 5 * 1024 * 1024,
}) {
  final FileFormat inFormat = input ?? FormatCatalog.mp4;
  final FileFormat outFormat = output ?? FormatCatalog.mkv;
  return ConversionRequest(
    input: FileInfo(
      path: '/tmp/$name',
      sizeBytes: sizeBytes,
      format: inFormat,
      width: 1920,
      height: 1080,
    ),
    outputFormat: outFormat,
    outputPath: '/tmp/out.${outFormat.extension}',
  );
}

/// Waits for the job's first terminal update.
Future<JobProgressUpdate> awaitTerminal(
  ConversionService service,
  String jobId,
) {
  return service.updates
      .where((JobProgressUpdate u) => u.jobId == jobId && u.status.isTerminal)
      .first;
}

void main() {
  late MockConversionService service;

  setUp(() async {
    // Very short simulated durations keep the suite fast.
    service = MockConversionService(timeScale: 0.02);
    await service.initialize(maxConcurrentJobs: 2);
  });

  tearDown(() async {
    if (service.isInitialized) await service.shutdown();
  });

  test('rejects use before initialisation', () async {
    final MockConversionService fresh = MockConversionService();
    expect(
      () => fresh.createJob(request()),
      throwsA(isA<ConversionServiceException>()),
    );
  });

  test('a created job starts queued and is readable by id', () async {
    final String id = await service.createJob(request());
    final JobProgressUpdate? status = service.statusOf(id);
    expect(status, isNotNull);
    expect(status!.status, JobStatus.queued);
    expect(status.progress, 0.0);
  });

  test('unknown job ids are reported, not silently ignored', () async {
    expect(service.statusOf('nope'), isNull);
    expect(
      () => service.startJob('nope'),
      throwsA(isA<ConversionServiceException>()),
    );
  });

  test('a started job progresses and completes', () async {
    // A scale that leaves room for several 120 ms progress ticks, so the
    // intermediate reporting is actually exercised.
    final MockConversionService paced = MockConversionService(timeScale: 0.15);
    await paced.initialize();
    addTearDown(paced.shutdown);

    final String id = await paced.createJob(request());

    final List<JobProgressUpdate> seen = <JobProgressUpdate>[];
    final StreamSubscription<JobProgressUpdate> sub = paced.updates
        .where((JobProgressUpdate u) => u.jobId == id)
        .listen(seen.add);

    await paced.startJob(id);
    final JobProgressUpdate terminal = await awaitTerminal(paced, id);
    await sub.cancel();

    expect(terminal.status, JobStatus.completed);
    expect(terminal.progress, 1.0);
    expect(terminal.outputSizeBytes, isNotNull);
    expect(terminal.error, isNull);

    // It reported running, with intermediate progress and a stage label.
    expect(seen.any((u) => u.status == JobStatus.running), isTrue);
    final List<JobProgressUpdate> mid = seen
        .where((u) => u.status == JobStatus.running && u.progress > 0)
        .toList();
    expect(mid, isNotEmpty);
    expect(mid.first.stage, isNotNull);

    // Progress is monotonic.
    double last = -1;
    for (final JobProgressUpdate u in seen.where((u) => !u.status.isTerminal)) {
      expect(u.progress, greaterThanOrEqualTo(last));
      last = u.progress;
    }
  });

  test('cancelling a queued job finishes it immediately', () async {
    final String id = await service.createJob(request());
    await service.cancelJob(id);
    expect(service.statusOf(id)!.status, JobStatus.cancelled);
  });

  test('cancelling a running job interrupts it', () async {
    // A long job so cancellation lands mid-run.
    final MockConversionService slow = MockConversionService(timeScale: 1.0);
    await slow.initialize();

    final String id = await slow.createJob(request(name: 'slow-clip.mp4'));
    await slow.startJob(id);

    // Wait until it is actually running before cancelling.
    await slow.updates
        .where(
          (JobProgressUpdate u) =>
              u.jobId == id && u.status == JobStatus.running,
        )
        .first;

    await slow.cancelJob(id);
    final JobProgressUpdate terminal = await awaitTerminal(slow, id);

    expect(terminal.status, JobStatus.cancelled);
    expect(terminal.progress, lessThan(1.0));
    await slow.shutdown();
  });

  test('a filename containing "fail" fails with a typed error', () async {
    final String id = await service.createJob(request(name: 'will-fail.mp4'));
    await service.startJob(id);
    final JobProgressUpdate terminal = await awaitTerminal(service, id);

    expect(terminal.status, JobStatus.failed);
    expect(terminal.error, isNotNull);
    expect(terminal.error!.details, isNotNull);
    expect(terminal.error!.exitCode, isNotNull);
  });

  test('an unsupported pair fails instead of pretending to work', () async {
    final String id = await service.createJob(
      ConversionRequest(
        input: const FileInfo(
          path: '/tmp/song.mp3',
          sizeBytes: 1024,
          format: FormatCatalog.mp3,
        ),
        outputFormat: FormatCatalog.mp4,
        outputPath: '/tmp/song.mp4',
      ),
    );
    await service.startJob(id);
    final JobProgressUpdate terminal = await awaitTerminal(service, id);
    expect(terminal.status, JobStatus.failed);
    expect(terminal.error!.code.label, 'Unsupported conversion');
  });

  test('honours the concurrency limit', () async {
    final MockConversionService limited = MockConversionService(
      timeScale: 0.35,
    );
    await limited.initialize(maxConcurrentJobs: 2);

    final List<String> ids = <String>[];
    for (int i = 0; i < 6; i++) {
      ids.add(await limited.createJob(request(name: 'clip$i.mp4')));
    }

    int maxObservedRunning = 0;
    final StreamSubscription<JobProgressUpdate> sub = limited.updates.listen((
      _,
    ) {
      final int running = ids
          .map(limited.statusOf)
          .where((JobProgressUpdate? u) => u?.status == JobStatus.running)
          .length;
      if (running > maxObservedRunning) maxObservedRunning = running;
    });

    for (final String id in ids) {
      await limited.startJob(id);
    }

    // Wait for every job to reach a terminal state.
    await Future.wait(ids.map((String id) => awaitTerminal(limited, id)));
    await sub.cancel();

    expect(maxObservedRunning, lessThanOrEqualTo(2));
    expect(maxObservedRunning, greaterThan(0));
    for (final String id in ids) {
      expect(limited.statusOf(id)!.status.isTerminal, isTrue);
    }
    await limited.shutdown();
  });

  test('raising the concurrency limit releases waiting jobs', () async {
    final MockConversionService limited = MockConversionService(
      timeScale: 0.25,
    );
    await limited.initialize(maxConcurrentJobs: 1);

    final List<String> ids = <String>[
      await limited.createJob(request(name: 'a.mp4')),
      await limited.createJob(request(name: 'b.mp4')),
      await limited.createJob(request(name: 'c.mp4')),
    ];
    for (final String id in ids) {
      await limited.startJob(id);
    }
    await limited.setMaxConcurrentJobs(3);

    await Future.wait(ids.map((String id) => awaitTerminal(limited, id)));
    for (final String id in ids) {
      expect(limited.statusOf(id)!.status.isTerminal, isTrue);
    }
    await limited.shutdown();
  });

  test('disposing a job forgets it', () async {
    final String id = await service.createJob(request());
    await service.disposeJob(id);
    expect(service.statusOf(id), isNull);
  });

  test('probe resolves format and metadata from the path', () async {
    final FileInfo video = await service.probe('/tmp/does-not-exist.mp4');
    expect(video.format, FormatCatalog.mp4);
    expect(video.probeFailed, isTrue, reason: 'missing file must be flagged');
    expect(video.duration, isNotNull);
    expect(video.width, isNotNull);

    final FileInfo unknown = await service.probe('/tmp/thing.xyz');
    expect(unknown.format, isNull);
    expect(unknown.isSupported, isFalse);
  });

  test('supportedOutputs matches the catalogue', () async {
    expect(
      await service.supportedOutputs(FormatCatalog.mp4),
      FormatCatalog.outputsFor(FormatCatalog.mp4),
    );
  });

  test('the engine reports itself as non-native during Stage 1', () {
    expect(service.engineInfo.isNative, isFalse);
  });
}
