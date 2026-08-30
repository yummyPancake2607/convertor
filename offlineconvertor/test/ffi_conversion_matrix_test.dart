import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/models/conversion_request.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/job_progress_update.dart';
import 'package:offlineconvertor/models/media_type.dart';
import 'package:offlineconvertor/models/job_status.dart';
import 'package:offlineconvertor/services/cpp_ffi_conversion_service.dart';

/// End-to-end checks against the real native engine.
///
/// These cover the conversions that used to report success while writing
/// nothing (or writing to the wrong path), so a regression shows up here rather
/// than as an empty results screen.
void main() {
  late CppFfiConversionService service;
  late Directory work;

  setUpAll(() async {
    work = await Directory.systemTemp.createTemp('convertor_matrix_');
    await _buildFixtures(work);
  });

  tearDownAll(() async {
    if (await work.exists()) await work.delete(recursive: true);
  });

  setUp(() async {
    service = CppFfiConversionService();
    await service.initialize();
  });

  tearDown(() async => service.shutdown());

  String? lastJobId;

  /// Runs one conversion and returns the output file once the job settles.
  Future<File> convert(String inputName, String outputId) async {
    final String inputPath = '${work.path}/$inputName';
    final FileFormat format = FormatCatalog.fromId(outputId)!;
    final String outputPath =
        '${work.path}/out_${inputName.replaceAll('.', '_')}.${format.extension}';

    final File output = File(outputPath);
    if (await output.exists()) await output.delete();

    final String jobId = await service.createJob(
      ConversionRequest(
        input: await service.probe(inputPath),
        outputFormat: format,
        outputPath: outputPath,
      ),
    );
    lastJobId = jobId;

    for (int i = 0; i < 300; i++) {
      final status = service.statusOf(jobId);
      if (status != null && status.status.isTerminal) {
        expect(
          status.status,
          JobStatus.completed,
          reason: '$inputName -> $outputId failed: ${status.error?.message}',
        );
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return output;
  }

  /// Asserts the file exists at exactly this path and starts with `magic`.
  Future<void> expectFile(File file, List<int> magic, String label) async {
    expect(
      await file.exists(),
      isTrue,
      reason: '$label produced no file at ${file.path}',
    );
    final int size = await file.length();
    expect(size, greaterThan(64), reason: '$label produced a $size byte file');

    final List<int> head = (await file.readAsBytes()).take(magic.length).toList();
    expect(head, magic, reason: '$label wrote the wrong file type');
  }

  test('probing a PDF succeeds instead of failing to open', () async {
    // Regression: every job was probed with FFmpeg, which cannot open a PDF,
    // so document jobs died with "Error(302): Failed to open" before any
    // converter ran.
    final info = await service.probe('${work.path}/doc.pdf');
    expect(info.probeFailed, isFalse);
    expect(info.format?.id, 'pdf');
    expect(info.sizeBytes, greaterThan(0));
  });

  test('a PDF becomes a Word document', () async {
    final File out = await convert('doc.pdf', 'docx');
    await expectFile(out, <int>[0x50, 0x4B], 'pdf -> docx');   // ZIP header

    // A Word file is a ZIP package; the body part is what makes it openable.
    final String raw = String.fromCharCodes(await out.readAsBytes());
    expect(raw, contains('word/document.xml'));
  });

  test('image to image writes to the requested path', () async {
    // Regression: FrameExtractor claimed image jobs (a PNG has an FFmpeg
    // "video" stream), swallowed every error and reported success without
    // writing anything.
    await expectFile(
      await convert('still.png', 'jpg'),
      <int>[0xFF, 0xD8, 0xFF],
      'png -> jpg',
    );
  });

  test('png output is really a PNG, not JPEG bytes', () async {
    // Regression: the image2 muxer defaults to MJPEG, so ".png" files held
    // JPEG data.
    await expectFile(
      await convert('still.jpg', 'png'),
      <int>[0x89, 0x50, 0x4E, 0x47],
      'jpg -> png',
    );
  });

  test('a video is never offered as a still image', () async {
    // Exporting one frame of a video as a picture is deliberately not a
    // conversion this app does, so it must not appear for any video input.
    for (final FileFormat input in FormatCatalog.videoFormats) {
      if (!input.canRead) continue;
      final Iterable<String> imageTargets = FormatCatalog.outputsFor(input)
          .where((FileFormat f) => f.mediaType == MediaType.image)
          .map((FileFormat f) => f.id);
      expect(imageTargets, isEmpty,
          reason: '${input.id} still offers image targets: $imageTargets');
    }

    // The engine must agree, so a direct request cannot sneak past the UI.
    final engineTargets =
        (await service.supportedOutputs(FormatCatalog.mp4)).map((f) => f.id);
    expect(engineTargets, isNot(contains('png')));
    expect(engineTargets, isNot(contains('jpg')));
  });

  test('video transcode keeps its full duration and audio track', () async {
    // Regression: WebM came out 0.002s long with the audio silently dropped.
    final File out = await convert('clip.mp4', 'webm');
    expect(await out.exists(), isTrue);

    final probe = await Process.run('ffprobe', <String>[
      '-v', 'error',
      '-show_entries', 'format=duration:stream=codec_type',
      '-of', 'default=nw=1', out.path,
    ]);
    final String report = probe.stdout as String;
    expect(report, contains('codec_type=video'));
    expect(report, contains('codec_type=audio'));

    final double duration = double.parse(
      RegExp(r'duration=([\d.]+)').firstMatch(report)!.group(1)!,
    );
    expect(duration, greaterThan(1.5),
        reason: 'transcode collapsed the timeline to $duration s');
  });

  test('a finished job reports the size of what it wrote', () async {
    // Regression: the results screen showed "377 KB -> 0 B" because the FFI
    // service never filled in outputSizeBytes.
    final File out = await convert('still.png', 'jpg');
    final int onDisk = await out.length();

    final JobProgressUpdate? update = service
        .statusOf(lastJobId!);
    expect(update, isNotNull);
    expect(update!.outputSizeBytes, onDisk);
  });

  test('a Word document becomes a PDF that opens', () async {
    final File docx = await convert('doc.pdf', 'docx');
    await File('${work.path}/round.docx').writeAsBytes(await docx.readAsBytes());

    final File out = await convert('round.docx', 'pdf');
    await expectFile(out, <int>[0x25, 0x50, 0x44, 0x46], 'docx -> pdf');

    // Reading it back with poppler is what proves the writer produced a real
    // PDF rather than something that merely starts with the right bytes.
    final back = await Process.run('pdftotext', <String>[out.path, '-']);
    expect(back.exitCode, 0);
    expect((back.stdout as String).trim(), isNotEmpty);
  });

  test('documents offer Word and PDF only', () async {
    expect(FormatCatalog.outputsFor(FormatCatalog.pdf).map((f) => f.id),
        <String>['docx']);
    expect(FormatCatalog.outputsFor(FormatCatalog.docx).map((f) => f.id),
        <String>['pdf']);

    // The engine must agree, so nothing else can be requested directly.
    expect((await service.supportedOutputs(FormatCatalog.pdf)).map((f) => f.id),
        <String>['docx']);
  });

  test('the UI offers exactly what the engine can do', () async {
    // The picker must never show a target the engine will refuse: this keeps
    // the Dart catalogue and the native catalogue from drifting apart.
    for (final FileFormat input in FormatCatalog.all.where((f) => f.canRead)) {
      final engineOutputs =
          (await service.supportedOutputs(input)).map((f) => f.id).toSet();
      if (engineOutputs.isEmpty) continue;

      final uiOutputs = FormatCatalog.outputsFor(input).map((f) => f.id).toSet();
      expect(
        uiOutputs.difference(engineOutputs),
        isEmpty,
        reason: '${input.id}: UI offers targets the engine does not support',
      );
    }
  });
}

Future<void> _buildFixtures(Directory dir) async {
  Future<void> ffmpeg(List<String> args) async {
    final r = await Process.run('ffmpeg', <String>['-hide_banner', '-loglevel', 'error', '-y', ...args]);
    if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
  }

  await ffmpeg(<String>[
    '-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=15:duration=2',
    '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest',
    '${dir.path}/clip.mp4',
  ]);
  await ffmpeg(<String>[
    '-f', 'lavfi', '-i', 'testsrc=size=160x120:duration=1', '-frames:v', '1',
    '${dir.path}/still.png',
  ]);
  await ffmpeg(<String>[
    '-f', 'lavfi', '-i', 'testsrc=size=160x120:duration=1', '-frames:v', '1',
    '${dir.path}/still.jpg',
  ]);

  // A PDF with a real text layer to convert from. It is a checked-in fixture
  // because the engine no longer converts text to PDF, so there is nothing to
  // generate one with, and a rendered image carries no text to extract.
  await File('test_assets/sample.pdf').copy('${dir.path}/doc.pdf');

}
