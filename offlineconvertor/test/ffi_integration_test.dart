import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlineconvertor/services/cpp_ffi_conversion_service.dart';
import 'package:offlineconvertor/services/conversion_service.dart';
import 'package:offlineconvertor/models/conversion_request.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/file_info.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';

void main() {
  late CppFfiConversionService service;

  setUp(() async {
    service = CppFfiConversionService();
    await service.initialize(maxConcurrentJobs: 2);
  });

  tearDown(() async {
    await service.shutdown();
  });

  test('engine loads and reports native', () {
    expect(service.isInitialized, isTrue);
    expect(service.engineInfo.isNative, isTrue);
    expect(service.engineInfo.version, isNotEmpty);
    print('Engine version: ${service.engineInfo.version}');
  });

  test('probe returns file info', () async {
    // Create a test file
    final result = await Process.run('ffmpeg', [
      '-y', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=320x240:rate=24',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest',
      '/tmp/test_ffi_integration.mp4',
    ]);
    expect(result.exitCode, 0);

    final info = await service.probe('/tmp/test_ffi_integration.mp4');
    print('Probe: path=${info.path} size=${info.sizeBytes} '
        'duration=${info.duration} '
        'w=${info.width} h=${info.height} '
        'video=${info.videoCodec} audio=${info.audioCodec} '
        'format=${info.format?.id}');
    expect(info.path, contains('test_ffi_integration.mp4'));
    expect(info.sizeBytes, greaterThan(0));
    expect(info.duration, isNotNull);
    expect(info.width, isNotNull);
    expect(info.height, isNotNull);
  });

  test('supportedOutputs returns formats', () async {
    final mp4 = FormatCatalog.fromId('mp4')!;
    final outputs = await service.supportedOutputs(mp4);
    print('mp4 outputs: ${outputs.map((f) => f.id).join(', ')}');
    expect(outputs, isNotEmpty);
    expect(outputs.map((f) => f.id), contains('mkv'));
  });

  test('full conversion: mp4 to mkv', () async {
    // Ensure input file exists
    final inputFile = File('/tmp/test_ffi_integration.mp4');
    expect(await inputFile.exists(), isTrue, reason: 'Test input file must exist');

    final inputInfo = await service.probe('/tmp/test_ffi_integration.mp4');
    final mkvFormat = FormatCatalog.fromId('mkv')!;

    final outputPath = '/tmp/test_ffi_integration_output.mkv';
    // Clean up any previous output
    final outputFile = File(outputPath);
    if (await outputFile.exists()) await outputFile.delete();

    final request = ConversionRequest(
      input: inputInfo,
      outputFormat: mkvFormat,
      outputPath: outputPath,
    );

    // Listen for updates
    final updates = <dynamic>[];
    service.updates.listen((u) {
      updates.add(u);
      print('  Update: status=${u.status} progress=${u.progress} stage=${u.stage}');
    });

    // Create and start job
    final jobId = await service.createJob(request);
    print('Job created: $jobId');
    expect(jobId, isNotEmpty);

    // Wait for completion
    for (int i = 0; i < 50; i++) {
      final status = service.statusOf(jobId);
      if (status != null && status.status.isTerminal) {
        print('Final status: ${status.status} progress=${status.progress}');
        break;
      }
      await Future.delayed(Duration(milliseconds: 200));
    }

    // Verify output
    expect(await outputFile.exists(), isTrue, reason: 'Output file must exist');
    final size = await outputFile.length();
    print('Output file size: $size bytes');
    expect(size, greaterThan(1000), reason: 'Output must be real media, not placeholder');

    // Verify it's not a placeholder (check first few bytes)
    final bytes = await outputFile.readAsBytes();
    final header = String.fromCharCodes(bytes.take(64));
    expect(header.contains('placeholder'), isFalse, reason: 'Output must not be a placeholder');
    expect(header.contains('Convertor placeholder'), isFalse, reason: 'Output must not be a placeholder');

    print('SUCCESS: Real converted output produced!');
  });
}
