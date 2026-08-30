# Convertor — architecture

An offline file converter. A Flutter UI drives a native C++20 engine through a
flat C API; nothing leaves the device. This document explains what every piece
is, why it exists, and how a conversion actually flows through the system.

The repository holds two things:

```
engine/            the C++ conversion engine (this document's main subject)
offlineconvertor/  the Flutter app that drives it
```

---

## 1. The shape of the whole thing

```
   Flutter UI  (Dart)
        │  picks files, picks a target format, shows progress
        ▼
   ConversionService  (Dart interface)
        │
        ├── CppFfiConversionService ── dart:ffi ──┐   real engine
        └── MockConversionService                 │   fake, for UI work
                                                  ▼
                              libconvertor.so  ── C API (extern "C")
                                                  │
                                             Engine (C++ façade)
                                                  │
                                    JobManager ─→ worker threads
                                                  │
                                       ConverterRegistry picks a converter
                                                  │
              ┌───────────────┬───────────────────┼───────────────┐
              ▼               ▼                   ▼               ▼
        DocumentConverter  ImageConverter   Audio*/Remuxer   VideoConverter
              │               │                   │               │
           poppler         FFmpeg              FFmpeg          FFmpeg
           libzip
```

The Dart side never sees a C++ type, and the C++ side never knows Flutter
exists. The only contract between them is `engine_c_api.h`.

---

## 2. Layering rule

```
  tools/ ─┐                       CLI harness — runs the engine without Flutter
  ffi/  ──┤
          ├─→ jobs/ ─→ document/ ─→ ffmpeg/ ─→ [ libav* ]
          │                     └────────────→ [ poppler, libzip ]
          └─────────────→ fs/
                          core/                 (depends on nothing of ours)
```

A file may include from its own layer or any layer **below** it, never above.
If `document/` ever needs something from `jobs/`, the design is wrong — pass a
callback down instead. That is exactly how progress reporting works.

**FFmpeg headers appear only inside `src/ffmpeg/`.** Everywhere else sees our
own wrapper types. That keeps `AVFrame*` and `av_err2str` out of the conversion
logic and is what makes an FFmpeg version bump a contained change.

---

## 3. Third-party libraries, and why each is here

| Library | Used for | Why not something else |
|---|---|---|
| **FFmpeg** (avformat, avcodec, avutil, swscale, swresample, avfilter) | All audio, video and raster image work | Nothing else covers this many containers and codecs |
| **libx264** | H.264 encoding | FFmpeg has an H.264 *decoder* but no encoder. **This makes the app GPL** |
| **libmp3lame** | MP3 encoding | FFmpeg has no native MP3 encoder |
| **libvpx** | VP8/VP9 encoding, i.e. WebM output | FFmpeg has no native VP9 encoder |
| **libvorbis / libogg** | Ogg Vorbis encoding | The native Vorbis encoder is poor |
| **libopus** | Opus encoding | Better than the native encoder |
| **libwebp** | WebP encoding | FFmpeg has no native WebP encoder |
| **poppler** (poppler-cpp) | Reading PDFs: text extraction, page rendering | Mature, and buildable for Android; PDFium needs the full Chromium toolchain |
| **libzip** | Reading and writing ZIP containers — DOCX is a ZIP | zlib alone gives deflate but no archive format |
| **libiconv** | poppler-cpp needs it | Android's NDK ships no iconv |
| **FreeType** | poppler requires it | Not optional for poppler |

Writing PDFs is **ours** (`pdf_writer.cpp`) — no library involved. Writing DOCX
is ours too (`document_writers.cpp`), on top of libzip.

---

## 4. `include/convertor/` — the public API

The only headers `ffi/` and `tools/` may include. Nothing here mentions FFmpeg.

| File | Holds |
|---|---|
| `version.hpp` | Engine version |
| `error.hpp` | `ErrorCode`, `Error`, `Result<T>` — the error strategy |
| `logging.hpp` | `LogLevel`, logger, sinks (stdout, and logcat on Android) |
| `media_type.hpp` | `MediaType` (video/audio/image/document), `ConversionType` |
| `file_format.hpp` | `FileFormat` — one container/encoding and its targets |
| `format_catalog.hpp` | Every known format + which conversions exist |
| `media_info.hpp` | Probe result: duration, streams, dimensions, codecs |
| `conversion_settings.hpp` | Video/audio/image/document options |
| `conversion_request.hpp` | Input + output + settings = one unit of work |
| `conversion_result.hpp` | Output path, size, elapsed time |
| `job.hpp` | `JobId`, `JobStatus`, `Job` |
| `engine.hpp` | `Engine` — the façade the whole app talks to |
| `engine_c_api.h` | Flat C surface for Dart FFI (`extern "C"`) |

### The format catalogue is the contract

`FormatCatalog` (`src/core/format_catalog.cpp`) is the single source of truth
for *what the app offers*. It registers every format and, for each, the list of
targets it converts to. The current offering:

| From | To |
|---|---|
| Video (mp4, mkv, mov, webm, flv, ts, avi, wmv, m4v, 3gp, mpeg, ogv) | video containers, or any audio format |
| Audio (mp3, wav, flac, aac, ogg, m4a, opus, wma, aiff) | any audio format |
| Image (jpg, png, gif, bmp, webp, tiff, ico, avif) | any image format, or PDF |
| Document (pdf, docx) | each other — Word ⇄ PDF |

Two deliberate exclusions: a **video never converts to a still image** (one
arbitrary frame is rarely what was wanted), and **documents are Word and PDF
only**. Both are product decisions, enforced in the catalogue and pinned by
tests.

The Dart catalogue mirrors this table, and a test asserts the UI never offers a
target the engine would refuse.

---

## 5. `src/` walkthrough

### `src/core/` — no dependencies

Enums, the format catalogue, `Error`/`Result<T>`, logging, settings. Pure logic,
trivially testable, no I/O.

`Error` carries a code plus a message. There are no exceptions across the FFI
boundary — every failure comes back as an `Error`.

### `src/fs/` — filesystem

`path_utils` (join, extension, stem, change_extension), `file_system`, and
`temp_file` (RAII: deletes itself on scope exit). `TempFile` defaults to
`$TMPDIR`, falling back to `/tmp` — **Android has no `/tmp`**, so a hard-coded
path silently produced unusable scratch files there.

### `src/ffmpeg/` — RAII wrappers

The only place FFmpeg headers appear. Every raw `AV*` pointer gets a C++ owner
so nothing leaks on an early return:

| Wrapper | Owns |
|---|---|
| `FormatContext` | `AVFormatContext` for input and output; open, header, packets, trailer |
| `CodecContext` | `AVCodecContext` — decoder/encoder lifecycle |
| `Frame`, `Packet` | `AVFrame`, `AVPacket` |
| `Rescaler` | `SwsContext` — pixel format and size conversion |
| `Resampler` | `SwrContext` — sample rate, layout and format conversion |
| `ffmpeg_error` | Turns an FFmpeg return code into our `Error` |

`filter_graph` is a wrapper for `AVFilterGraph` that nothing currently uses; it
is compiled but dormant.

### `src/document/` — the converters

Despite the name this holds **every** converter, not just document ones.

**The probe** — `media_prober.cpp` opens the file with FFmpeg and reports
streams, duration and dimensions. Crucially, when FFmpeg *cannot* open a file it
does not fail: documents are expected to fail there, and the media type is taken
from the extension instead. Before that fallback existed, every PDF job died
with `Error(302): Failed to open` before any converter ran.

**Converter selection** — `ConverterRegistry` holds converters in registration
order and returns *all* that accept a request. `JobManager` tries them in turn:

```
DocumentConverter → ImageConverter → AudioExtractor → AudioConverter
                  → Remuxer → VideoConverter
```

Specific handlers come first, general ones last. `Remuxer` (a stream copy, and
therefore near-instant) is tried before `VideoConverter` (a full re-encode), and
if the container rejects the codecs the job falls through to the re-encode
instead of failing. That fallback is why `mpeg → mp4` and `webm → mov` work.

| Converter | Handles |
|---|---|
| `Remuxer` | Video → video where every stream can be copied as-is |
| `VideoConverter` | Video → video needing a re-encode; carries audio across, transcoding it when the container demands (AAC cannot go into WebM) |
| `AudioExtractor` | Video → audio |
| `AudioConverter` | Audio → audio |
| `ImageConverter` | Image → image |
| `DocumentConverter` | Word ⇄ PDF, and image → PDF |

`AudioTranscoder` is shared by all three audio paths. It decodes, resamples and
re-encodes through an `AVAudioFifo`, which is what keeps the encoder fed with
exactly `frame_size` samples per frame — MP3 requires that for every frame but
the last.

**The document pipeline** is a read/write split rather than a branch per pair:

```
  source file ──[reader]──→ DocumentContent ──[writer]──→ target file
```

`DocumentContent` (`document_content.hpp`) is either a flow of lines or a grid
of cells. Adding a format means adding one reader or one writer, not N pairs.

- `document_readers.cpp` — PDF (via poppler) and DOCX are wired up. Readers for
  RTF, ODF, EPUB, HTML and CSV are implemented and working but **not reachable**,
  because Word and PDF are the only documents on offer; `can_read()` is the one
  list that decides.
- `document_writers.cpp` — DOCX and PDF are wired up. Writers for XLSX, ODT,
  ODS, RTF and HTML are likewise implemented but not reachable, gated by
  `can_write_document()` in `document_converter.cpp`.
- `pdf_writer.cpp` — a real PDF 1.4 generator: text layout with wrapping and
  pagination, UTF-8 → WinAnsi mapping, and JPEG embedding for image → PDF.
- `zip_reader.cpp` / `zip_writer.cpp` — libzip. The writer holds each entry's
  bytes until close, because libzip reads from the caller's buffers lazily.
- `xml_text.cpp` — a small scanner used by every XML-shaped format. Machine
  generated office XML only needs its text runs and a few attributes, so this
  handles tags, entities, CDATA and comments without a full parser.
- `text_layout.cpp`, `format_detector.cpp` — compiled but currently dormant.

### `src/jobs/` — concurrency

`JobManager` owns a `WorkerPool` pulling from a `JobQueue`. `submit()` returns a
`JobId` immediately; the caller polls. Each job runs the probe, picks converters
and runs them, then records the result or error.

`progress_reporter` and `cancellation_token` are present but dormant — progress
is reported through the callback `JobManager` passes into `convert()`.

### `src/ffi/` — the C boundary

`engine_c_api.cpp` implements the 26 `extern "C"` functions. Rules it follows:

- **No exceptions escape.** Every function has a `try/catch(...)`.
- **No C++ types cross.** Pointers become opaque `uint64_t` handles via
  `HandleTable`.
- **Returned strings stay owned by the engine**, in `thread_local` storage, and
  are valid until the next call on that thread. Dart copies them immediately.

The surface: engine create/destroy, probe (and accessors), convert, job
status/progress/stage/error/cancel, supported outputs, version.

### `tools/` — the CLI

`convertor_cli convert|probe|formats` runs the engine with no Flutter involved.
This is what the conversion matrix harness drives, and it is the fastest way to
reproduce a bug.

---

## 6. The Flutter app

```
lib/
  main.dart                 composition root — builds the service, injects it
  app.dart                  MaterialApp + theme
  core/constants/           format_catalog.dart — mirror of the engine catalogue
  models/                   FileFormat, FileInfo, ConversionRequest, JobStatus…
  services/
    conversion_service.dart      the interface the UI codes against
    cpp_ffi_conversion_service.dart   the real one, over dart:ffi
    mock_conversion_service.dart      a fake, for UI work without the engine
    file_system_service.dart          picking, saving, opening (SAF on Android)
  providers/conversion_flow_provider.dart   the state machine for one batch
  features/home/            the four steps: category → configure → progress → results
```

`main.dart` tries to build `CppFfiConversionService` and falls back to the mock
if the library will not load. **That fallback is why the app once reported
success while writing 305-byte placeholder files**: Android had no
`libconvertor.so` at all. The results screen shows a warning banner whenever the
engine is not native, so the fallback is visible rather than silent.

`CppFfiConversionService` loads the library (`libconvertor.so` by bare name on
Android, where the loader finds it in the APK), binds each C function, and polls
job status on a 200 ms timer, emitting `JobProgressUpdate`s the provider listens
to.

---

## 7. Building

### Desktop (Linux)

Dependencies come from the system through `pkg-config`:

```sh
cd engine && mkdir -p build && cd build
cmake .. && cmake --build . -j
```

Produces `libconvertor.so`, `convertor_cli` and `convertor_tests`. Copy the
shared library to `offlineconvertor/linux/` for the Flutter desktop build.

### Android

Android ships none of these libraries, so all of them are cross-compiled with
the NDK and linked **statically into one `libconvertor.so`**. See
[`android/README.md`](android/README.md) for the step-by-step and for the
non-obvious decisions (why x86_64 gives up its assembly, why
`-Wl,--exclude-libs,ALL` is required, why libiconv is built at all).

Built for **arm64-v8a** and **x86_64** only; the APK excludes every other ABI so
no device gets a build with no engine behind it.

### Exporting the app

`build_engine.sh` installs straight into `android/app/src/main/jniLibs/<abi>/`,
so once both ABIs are built the Flutter build picks them up:

```sh
cd offlineconvertor
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter build apk --release --target-platform android-arm64,android-x64
```

Deleting the generated plugin registrant matters: a debug or test run rewrites
it to include `integration_test`, which release builds exclude, and the Gradle
build then fails on a missing package. For the same reason, **never run
`flutter test` and `flutter build` at the same time** — they race on that file.

---

## 8. Testing

| Layer | What it covers |
|---|---|
| `engine/tests/` | Unit tests for error codes, media types, the catalogue, path utils |
| `offlineconvertor/test/` | Dart unit tests, plus `ffi_conversion_matrix_test.dart` which drives the **real** engine |
| `offlineconvertor/integration_test/` | The same, on a real device or emulator |
| Conversion matrix harness | Every advertised pair, end to end, with output validation |

Two properties are worth calling out because they catch whole classes of bug:

- **The UI can never drift from the engine.** A test asks the engine what it
  supports and asserts the Dart catalogue offers nothing more.
- **Outputs are validated, not just counted.** Media is fully decoded, images
  are checked against their magic bytes, PDFs are re-read with poppler, and
  Office files are checked for their required package parts. "It produced a
  file" is not evidence — the original bug produced files that were empty, or
  JPEG data inside a `.png`.
