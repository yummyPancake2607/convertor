import 'package:flutter_test/flutter_test.dart';
import 'package:offlineconvertor/core/constants/format_catalog.dart';
import 'package:offlineconvertor/models/file_format.dart';
import 'package:offlineconvertor/models/media_type.dart';

void main() {
  group('extension resolution', () {
    test('resolves canonical extensions', () {
      expect(FormatCatalog.fromExtension('mp4'), FormatCatalog.mp4);
      expect(FormatCatalog.fromExtension('MP4'), FormatCatalog.mp4);
      expect(FormatCatalog.fromExtension('.mp4'), FormatCatalog.mp4);
    });

    test('resolves aliases onto the canonical format', () {
      expect(FormatCatalog.fromExtension('jpeg'), FormatCatalog.jpg);
      expect(FormatCatalog.fromExtension('tif'), FormatCatalog.tiff);
      expect(FormatCatalog.fromExtension('mpg'), FormatCatalog.mpeg);
      expect(FormatCatalog.fromExtension('htm'), FormatCatalog.html);
    });

    test('returns null for unknown extensions', () {
      expect(FormatCatalog.fromExtension('xyz'), isNull);
      expect(FormatCatalog.fromExtension(''), isNull);
    });
  });

  group('conversion matrix', () {
    test('video offers video and audio targets, never a still image', () {
      final List<FileFormat> outputs = FormatCatalog.outputsFor(
        FormatCatalog.mp4,
      );
      expect(outputs, contains(FormatCatalog.mkv));
      expect(outputs, contains(FormatCatalog.mp3));

      // Pulling one frame out of a video is not a conversion this app offers.
      expect(
        outputs.every(
          (FileFormat f) =>
              f.mediaType == MediaType.video || f.mediaType == MediaType.audio,
        ),
        isTrue,
        reason: 'video should only convert to video or audio',
      );
    });

    test('audio offers only audio targets', () {
      final List<FileFormat> outputs = FormatCatalog.outputsFor(
        FormatCatalog.wav,
      );
      expect(
        outputs.every((FileFormat f) => f.mediaType == MediaType.audio),
        isTrue,
      );
      expect(outputs, contains(FormatCatalog.mp3));
      expect(outputs, contains(FormatCatalog.flac));
    });

    test('image offers image targets plus PDF', () {
      final List<FileFormat> outputs = FormatCatalog.outputsFor(
        FormatCatalog.png,
      );
      expect(outputs, contains(FormatCatalog.jpg));
      expect(outputs, contains(FormatCatalog.webpFormat));
      expect(outputs, contains(FormatCatalog.pdf));
    });

    test('documents offer Word and PDF only', () {
      // The app converts Word to PDF and PDF to Word; nothing else in the
      // document category is on offer, so nothing else may appear here.
      expect(
        FormatCatalog.outputsFor(FormatCatalog.pdf),
        <FileFormat>[FormatCatalog.docx],
      );
      expect(
        FormatCatalog.outputsFor(FormatCatalog.docx),
        <FileFormat>[FormatCatalog.pdf],
      );
    });

    test('never offers a no-op conversion', () {
      for (final FileFormat input in FormatCatalog.all) {
        expect(
          FormatCatalog.outputsFor(input),
          isNot(contains(input)),
          reason: '${input.id} offered itself as an output',
        );
      }
    });

    test('never offers a read-only format as an output', () {
      for (final FileFormat input in FormatCatalog.all) {
        for (final FileFormat output in FormatCatalog.outputsFor(input)) {
          expect(
            output.canWrite,
            isTrue,
            reason: '${input.id} offered non-writable ${output.id}',
          );
        }
      }
    });

    test('every readable format has at least one target', () {
      for (final FileFormat input in FormatCatalog.all.where(
        (FileFormat f) => f.canRead,
      )) {
        expect(
          FormatCatalog.outputsFor(input),
          isNotEmpty,
          reason: '${input.id} has no available outputs',
        );
      }
    });
  });

  group('defaults', () {
    test('picks the sensible target per media type', () {
      expect(
        FormatCatalog.defaultOutputFor(FormatCatalog.mkv),
        FormatCatalog.mp4,
      );
      expect(
        FormatCatalog.defaultOutputFor(FormatCatalog.wav),
        FormatCatalog.mp3,
      );
      expect(
        FormatCatalog.defaultOutputFor(FormatCatalog.jpg),
        FormatCatalog.png,
      );
      expect(
        FormatCatalog.defaultOutputFor(FormatCatalog.docx),
        FormatCatalog.pdf,
      );
    });

    test('falls back when the preferred target is the input itself', () {
      // MP4 cannot default to MP4; it must pick something else.
      final FileFormat fallback = FormatCatalog.defaultOutputFor(
        FormatCatalog.mp4,
      );
      expect(fallback, isNot(FormatCatalog.mp4));
      expect(FormatCatalog.outputsFor(FormatCatalog.mp4), contains(fallback));
    });

    test('the default is always a supported pair', () {
      for (final FileFormat input in FormatCatalog.all.where(
        (FileFormat f) => f.canRead,
      )) {
        final FileFormat target = FormatCatalog.defaultOutputFor(input);
        expect(
          FormatCatalog.isSupportedPair(input, target),
          isTrue,
          reason: '${input.id} -> ${target.id} is not a supported pair',
        );
      }
    });
  });

  test('conversion type resolves from the media pair', () {
    expect(
      ConversionType.resolve(MediaType.video, MediaType.audio),
      ConversionType.videoToAudio,
    );
    expect(
      ConversionType.resolve(MediaType.image, MediaType.document),
      ConversionType.imageToDocument,
    );
    expect(
      ConversionType.resolve(MediaType.audio, MediaType.video),
      ConversionType.unsupported,
    );
  });
}
