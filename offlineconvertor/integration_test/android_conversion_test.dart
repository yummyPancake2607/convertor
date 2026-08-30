import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/models/conversion_request.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/job_status.dart';
import 'package:offlineconvertor/services/cpp_ffi_conversion_service.dart';
import 'package:path_provider/path_provider.dart';

/// Runs the native engine on a real device/emulator.
///
/// The desktop suite proves the engine logic; this proves the Android build of
/// it actually loads and produces real files, which is exactly what the mock
/// fallback used to hide.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CppFfiConversionService service;
  late Directory work;

  setUpAll(() async {
    work = Directory('${(await getTemporaryDirectory()).path}/conv_test');
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);

    for (final String name in <String>[
      'sample.mp4', 'sample.png', 'sample.wav',
      'sample.pdf', 'sample.docx',
    ]) {
      final ByteData data = await rootBundle.load('test_assets/$name');
      await File('${work.path}/$name').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    service = CppFfiConversionService();
    await service.initialize();
  });

  tearDownAll(() async => service.shutdown());

  Future<File> convert(String input, String outputId) async {
    final FileFormat format = FormatCatalog.fromId(outputId)!;
    final String outPath =
        '${work.path}/${input.split('.').first}_to_$outputId.${format.extension}';
    final File out = File(outPath);
    if (await out.exists()) await out.delete();

    final String jobId = await service.createJob(
      ConversionRequest(
        input: await service.probe('${work.path}/$input'),
        outputFormat: format,
        outputPath: outPath,
      ),
    );

    for (int i = 0; i < 600; i++) {
      final status = service.statusOf(jobId);
      if (status != null && status.status.isTerminal) {
        expect(status.status, JobStatus.completed,
            reason: '$input -> $outputId: ${status.error?.message}');
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return out;
  }

  Future<void> expectMagic(File f, List<int> magic, String label) async {
    expect(await f.exists(), isTrue, reason: '$label wrote no file');
    final int size = await f.length();
    expect(size, greaterThan(200), reason: '$label wrote only $size bytes');

    final List<int> head =
        (await f.readAsBytes()).take(magic.length).toList();
    expect(head, magic, reason: '$label produced the wrong file type');
  }

  test('the native engine is loaded, not the mock', () {
    expect(service.engineInfo.isNative, isTrue);
    expect(service.engineInfo.version, isNotEmpty);
  });

  test('video transcode produces a real file', () async {
    final File out = await convert('sample.mp4', 'mkv');
    expect(await out.exists(), isTrue);
    // Matroska magic.
    await expectMagic(out, <int>[0x1A, 0x45, 0xDF, 0xA3], 'mp4 -> mkv');
    expect(await out.length(), greaterThan(2000));
  });

  test('audio extraction produces a real MP3', () async {
    final File out = await convert('sample.mp4', 'mp3');
    expect(await out.exists(), isTrue);
    expect(await out.length(), greaterThan(1000));
  });

  test('audio transcode produces a real FLAC', () async {
    await expectMagic(
        await convert('sample.wav', 'flac'), 'fLaC'.codeUnits, 'wav -> flac');
  });

  test('image conversion produces a real JPEG', () async {
    await expectMagic(
        await convert('sample.png', 'jpg'), <int>[0xFF, 0xD8, 0xFF], 'png -> jpg');
  });

  test('a PDF becomes a Word document', () async {
    final File out = await convert('sample.pdf', 'docx');
    await expectMagic(out, <int>[0x50, 0x4B], 'pdf -> docx');

    final String raw = String.fromCharCodes(await out.readAsBytes());
    expect(raw, contains('word/document.xml'));
  });

  test('a Word document becomes a PDF', () async {
    await expectMagic(await convert('sample.docx', 'pdf'),
        <int>[0x25, 0x50, 0x44, 0x46], 'docx -> pdf');
  });

  test('nothing produced is a mock placeholder', () async {
    for (final FileSystemEntity e in work.listSync()) {
      if (e is! File || !e.path.contains('_to_')) continue;
      final String head = String.fromCharCodes(
          (await e.readAsBytes()).take(64).where((b) => b >= 9 && b < 127));
      expect(head.contains('placeholder'), isFalse,
          reason: '${e.path} is a placeholder, not a conversion');
    }
  });
}
