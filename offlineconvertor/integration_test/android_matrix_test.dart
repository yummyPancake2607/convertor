import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/models/conversion_request.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/file_info.dart';
import 'package:offlineconvertor/models/job_status.dart';
import 'package:offlineconvertor/services/cpp_ffi_conversion_service.dart';
import 'package:path_provider/path_provider.dart';

/// Runs every conversion the UI offers for each bundled sample, on the device.
///
/// The desktop suite covers the whole catalogue; this checks the Android build
/// of the same engine agrees, so a codec left out of the cross-compile shows up
/// here rather than as a failed job in someone's hands.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const List<String> samples = <String>[
    'sample.mp4', 'sample.wav', 'sample.png',
    'sample.pdf', 'sample.docx',
  ];

  late CppFfiConversionService service;
  late Directory work;

  setUpAll(() async {
    work = Directory('${(await getTemporaryDirectory()).path}/conv_matrix');
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);

    for (final String name in samples) {
      final ByteData data = await rootBundle.load('test_assets/$name');
      await File('${work.path}/$name').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    service = CppFfiConversionService();
    await service.initialize();
  });

  tearDownAll(() async => service.shutdown());

  test('every offered conversion produces a real file on device', () async {
    final List<String> failures = <String>[];
    int passed = 0;

    for (final String sample in samples) {
      final FileInfo info = await service.probe('${work.path}/$sample');
      final FileFormat? input = info.format;
      if (input == null) {
        failures.add('$sample: not recognised by the engine');
        continue;
      }

      for (final FileFormat target in FormatCatalog.outputsFor(input)) {
        final String label = '${input.id} -> ${target.id}';
        final String outPath =
            '${work.path}/${input.id}_to_${target.id}.${target.extension}';
        final File out = File(outPath);
        if (await out.exists()) await out.delete();

        try {
          final String jobId = await service.createJob(
            ConversionRequest(
              input: info,
              outputFormat: target,
              outputPath: outPath,
            ),
          );

          JobStatus? finalStatus;
          String? error;
          for (int i = 0; i < 1200; i++) {
            final update = service.statusOf(jobId);
            if (update != null && update.status.isTerminal) {
              finalStatus = update.status;
              error = update.error?.message;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          await service.disposeJob(jobId);

          if (finalStatus != JobStatus.completed) {
            failures.add('$label: ${finalStatus?.name ?? "timed out"}'
                '${error != null ? " ($error)" : ""}');
            continue;
          }
          // Text results are legitimately tiny for these samples, so only
          // require that something real was written; binary containers carry
          // enough header to justify a floor.
          const Set<String> textTargets = <String>{'txt', 'md', 'csv'};
          final int minimumBytes = textTargets.contains(target.id) ? 1 : 64;
          if (!await out.exists() || await out.length() < minimumBytes) {
            failures.add('$label: completed but wrote no real file');
            continue;
          }
          passed++;
        } catch (e) {
          failures.add('$label: threw $e');
        }
      }
    }

    // ignore: avoid_print
    print('ON-DEVICE MATRIX: $passed passed, ${failures.length} failed');
    for (final String f in failures) {
      // ignore: avoid_print
      print('  FAIL $f');
    }

    expect(passed, greaterThan(0));
    expect(failures, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
