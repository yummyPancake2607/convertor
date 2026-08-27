import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/core/utils/path_utils.dart';
import 'package:offlineconvertor/models/conversion_job.dart';
import 'package:offlineconvertor/models/job_status.dart';
import 'package:offlineconvertor/models/media_type.dart';
import 'package:offlineconvertor/providers/conversion_flow_provider.dart';
import 'package:offlineconvertor/services/file_system_service.dart';
import 'package:offlineconvertor/services/mock_conversion_service.dart';

/// Stands in for the platform picker and app directories.
///
/// Only the parts that need the OS are replaced; the real path handling,
/// collision resolution and directory creation are exercised as written.
class StubFileSystem extends FileSystemService {
  StubFileSystem(this.root);

  final Directory root;

  /// Paths the next pick should return.
  List<String> nextPick = <String>[];

  int pickCalls = 0;

  @override
  Future<List<String>> pickFilesFor(MediaType category) async {
    pickCalls++;
    return nextPick;
  }

  @override
  Future<String> workingOutputDirectory() async {
    final String path = PathUtils.join(root.path, 'out');
    await ensureDirectory(path);
    return path;
  }

  @override
  Future<String> systemTemporaryDirectory() async => root.path;
}

void main() {
  late Directory dir;
  late StubFileSystem fs;
  late MockConversionService service;
  late ConversionFlowProvider flow;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('flow_test_');
    fs = StubFileSystem(dir);
    // Short simulated durations keep the suite quick.
    service = MockConversionService(timeScale: 0.05);
    await service.initialize(maxConcurrentJobs: 2);
    flow = ConversionFlowProvider(
      conversionService: service,
      fileSystem: fs,
    );
  });

  tearDown(() async {
    flow.dispose();
    await service.shutdown();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Creates a real file so probing and output writing are genuine.
  Future<String> makeFile(String name, {int bytes = 4096}) async {
    final File f = File(PathUtils.join(dir.path, name));
    await f.writeAsBytes(List<int>.filled(bytes, 0));
    return f.path;
  }

  Future<void> waitForStage(
    FlowStage stage, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (flow.stage != stage) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $stage (still ${flow.stage})');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('starts on the category step with nothing staged', () {
    expect(flow.stage, FlowStage.chooseCategory);
    expect(flow.hasFiles, isFalse);
    expect(flow.category, isNull);
  });

  test('dismissing the picker leaves the user on the category step', () async {
    fs.nextPick = <String>[];
    await flow.chooseCategory(MediaType.audio);

    expect(fs.pickCalls, 1);
    expect(flow.stage, FlowStage.chooseCategory);
    expect(flow.category, isNull);
  });

  test('choosing a category picks files and moves to configure', () async {
    fs.nextPick = <String>[
      await makeFile('one.wav'),
      await makeFile('two.wav'),
    ];
    await flow.chooseCategory(MediaType.audio);

    expect(flow.stage, FlowStage.configure);
    expect(flow.category, MediaType.audio);
    expect(flow.fileCount, 2);
    expect(flow.convertibleFiles, hasLength(2));

    // A sensible target is preselected, and it is a real option.
    expect(flow.outputFormat, isNotNull);
    expect(flow.availableFormats, contains(flow.outputFormat));
    expect(flow.canConvert, isTrue);
  });

  test('offered formats are only those every staged file can produce', () async {
    fs.nextPick = <String>[await makeFile('clip.mp4')];
    await flow.chooseCategory(MediaType.video);

    // A video can also become audio, which is the useful cross-category case.
    expect(flow.availableFormats, contains(FormatCatalog.mp3));
    expect(flow.availableFormats, contains(FormatCatalog.mkv));
    // Never a no-op.
    expect(flow.availableFormats, isNot(contains(FormatCatalog.mp4)));
  });

  test('duplicate picks are ignored', () async {
    final String path = await makeFile('one.wav');
    fs.nextPick = <String>[path];
    await flow.chooseCategory(MediaType.audio);
    expect(flow.fileCount, 1);

    await flow.pickFiles();
    expect(flow.fileCount, 1);
  });

  test('unsupported files are staged with a reason and skipped', () async {
    fs.nextPick = <String>[
      await makeFile('good.wav'),
      await makeFile('mystery.xyz'),
    ];
    await flow.chooseCategory(MediaType.audio);

    expect(flow.fileCount, 2);
    expect(flow.problemFiles, hasLength(1));
    expect(flow.problemFiles.single.problem, contains('.xyz'));
    expect(flow.convertibleFiles, hasLength(1));
  });

  test('removing the last file returns to the category step', () async {
    fs.nextPick = <String>[await makeFile('one.wav')];
    await flow.chooseCategory(MediaType.audio);

    flow.removeFile(flow.files.single.id);
    expect(flow.stage, FlowStage.chooseCategory);
    expect(flow.hasFiles, isFalse);
  });

  test('full flow: convert two files, then save the results', () async {
    fs.nextPick = <String>[
      await makeFile('one.wav', bytes: 20000),
      await makeFile('two.wav', bytes: 50000),
    ];
    await flow.chooseCategory(MediaType.audio);
    flow.setOutputFormat(FormatCatalog.mp3);

    await flow.startConversion();
    expect(flow.stage, FlowStage.converting);
    expect(flow.jobs, hasLength(2));

    await waitForStage(FlowStage.results);

    // Every job reached a terminal state and progress is complete.
    expect(flow.isConverting, isFalse);
    expect(
      flow.jobs.every((ConversionJob j) => j.status.isTerminal),
      isTrue,
    );
    expect(flow.overallProgress, 1.0);

    // Successful jobs produced a real file on disk with the right name.
    for (final ConversionJob job in flow.successfulJobs) {
      expect(job.outputFormat, FormatCatalog.mp3);
      expect(PathUtils.extension(job.outputPath), 'mp3');
      expect(
        await File(job.outputPath).exists(),
        isTrue,
        reason: 'no output produced for ${job.fileName}',
      );
      expect(job.outputSizeBytes, greaterThan(0));
      expect(job.startedAt, isNotNull);
      expect(job.finishedAt, isNotNull);
    }
    expect(flow.hasSavableResults, isTrue);
  });

  test('a failing conversion is reported without stalling the batch', () async {
    fs.nextPick = <String>[
      await makeFile('will-fail.wav'),
      await makeFile('fine.wav'),
    ];
    await flow.chooseCategory(MediaType.audio);
    await flow.startConversion();
    await waitForStage(FlowStage.results);

    final ConversionJob failed = flow.jobs.firstWhere(
      (ConversionJob j) => j.fileName == 'will-fail.wav',
    );
    expect(failed.status, JobStatus.failed);
    expect(failed.error, isNotNull);
    expect(failed.error!.details, isNotNull);

    // The other file still finished.
    expect(flow.jobs.length, 2);
    expect(flow.isConverting, isFalse);
  });

  test('failed jobs can be retried', () async {
    fs.nextPick = <String>[await makeFile('will-fail.wav')];
    await flow.chooseCategory(MediaType.audio);
    await flow.startConversion();
    await waitForStage(FlowStage.results);

    final String originalId = flow.jobs.single.id;
    expect(flow.failedCount, 1);

    await flow.retryFailed();
    await waitForStage(FlowStage.results);

    expect(flow.jobs.single.attempt, 2);
    expect(flow.jobs.single.id, isNot(originalId));
  });

  test('cancelling stops the batch and still reaches results', () async {
    // Long enough that cancellation lands mid-run.
    final MockConversionService slow = MockConversionService(timeScale: 3.0);
    await slow.initialize(maxConcurrentJobs: 2);
    final ConversionFlowProvider slowFlow = ConversionFlowProvider(
      conversionService: slow,
      fileSystem: fs,
    );
    addTearDown(() async {
      slowFlow.dispose();
      await slow.shutdown();
    });

    fs.nextPick = <String>[await makeFile('slow-one.wav')];
    await slowFlow.chooseCategory(MediaType.audio);
    await slowFlow.startConversion();

    // Wait until it is genuinely running before cancelling.
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 15));
    while (slowFlow.runningCount == 0) {
      if (DateTime.now().isAfter(deadline)) fail('job never started');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    await slowFlow.cancelAll();

    final DateTime end = DateTime.now().add(const Duration(seconds: 15));
    while (slowFlow.stage != FlowStage.results) {
      if (DateTime.now().isAfter(end)) fail('never reached results');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(slowFlow.cancelledCount, 1);
    expect(slowFlow.hasSavableResults, isFalse);
  });

  test('reset clears everything back to the start', () async {
    fs.nextPick = <String>[await makeFile('one.wav')];
    await flow.chooseCategory(MediaType.audio);
    await flow.startConversion();
    await waitForStage(FlowStage.results);

    await flow.reset();

    expect(flow.stage, FlowStage.chooseCategory);
    expect(flow.hasFiles, isFalse);
    expect(flow.jobs, isEmpty);
    expect(flow.category, isNull);
    expect(flow.outputFormat, isNull);
  });

  test('a new batch does not inherit the previous outputs', () async {
    fs.nextPick = <String>[await makeFile('first.wav')];
    await flow.chooseCategory(MediaType.audio);
    await flow.startConversion();
    await waitForStage(FlowStage.results);
    final String firstOutput = flow.jobs.single.outputPath;

    await flow.reset();
    fs.nextPick = <String>[await makeFile('second.wav')];
    await flow.chooseCategory(MediaType.audio);
    await flow.startConversion();
    await waitForStage(FlowStage.results);

    // The working folder was cleared, so the earlier result is gone.
    expect(await File(firstOutput).exists(), isFalse);
    expect(await File(flow.jobs.single.outputPath).exists(), isTrue);
  });
}
