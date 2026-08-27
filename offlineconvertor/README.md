# Convertor — Offline Universal File Converter

A desktop application for converting video, audio, image and document files.
Everything runs locally: no cloud service, no conversion API, no local HTTP
server. Once installed it works with the network disconnected.

**Status: Stage 1 complete.** The full Flutter frontend is built and functional
against a simulated conversion engine. Stage 2 replaces that simulation with a
native C++ engine over Dart FFI.

---

## Architecture

Today:

```text
Flutter UI  ->  Providers (controllers)  ->  ConversionService  ->  MockConversionService
```

After Stage 2:

```text
Flutter UI  ->  Providers (controllers)  ->  ConversionService  ->  CppFfiConversionService
                                                                      |
                                                              C-compatible FFI API
                                                                      |
                                                            C++ Conversion Engine
                                                                      |
                                                  FFmpeg / image engine / document engine
```

The UI and the controllers do not know which implementation is running.

### The Stage 2 seam

`lib/services/conversion_service.dart` is the whole boundary. It is deliberately
shaped like the C API the engine will expose:

| Dart                        | C++ FFI                     |
| --------------------------- | --------------------------- |
| `initialize()`              | `engine_initialize()`       |
| `createJob(request)`        | `engine_create_job()`       |
| `startJob(id)`              | `engine_start_job(id)`      |
| `cancelJob(id)`             | `engine_cancel_job(id)`     |
| `disposeJob(id)`            | `engine_destroy_job(id)`    |
| `statusOf(id)`              | `engine_get_job_status(id)` |
| `updates` stream            | progress callback / polling |
| `setMaxConcurrentJobs(n)`   | worker-pool resize          |
| `probe(path)`               | format detection            |
| `shutdown()`                | `engine_shutdown()`         |

Swapping implementations is one line, in `lib/main.dart`:

```dart
ConversionService _buildConversionService() => MockConversionService();
// Stage 2: => CppFfiConversionService();
```

Supporting types are already engine-shaped too: `JobStatus` mirrors the C++
enum, `JobProgressUpdate` is exactly what a status call returns, and
`ConversionErrorCode` is a typed failure taxonomy rather than error strings.

---

## Project layout

```text
lib/
├── core/
│   ├── constants/     app metadata, navigation sections, format catalogue
│   ├── theme/         palette tokens, spacing scale, type scale, ThemeData
│   ├── utils/         display formatters, path helpers
│   └── extensions/    context.palette, context.text, responsive helpers
├── models/            domain types (formats, jobs, settings, errors, history)
├── services/          engine boundary + filesystem + local persistence
├── providers/         controllers: navigation, settings, converter, queue, history
├── features/
│   ├── shell/         window chrome, sidebar, shared page frame
│   ├── dashboard/     totals, live progress, recent results, breakdown
│   ├── converter/     staging list, format pickers, settings forms
│   ├── queue/         job rows, progress, per-job actions
│   ├── history/       persisted records, search and filters
│   └── settings/      output, engine, behaviour, notifications
├── widgets/           shared UI primitives
├── app.dart           theming + shell installation
└── main.dart          composition root (all dependencies constructed here)
```

### Format catalogue

`core/constants/format_catalog.dart` is the single source of truth for what
converts to what. It answers the question the engine will answer later — *given
this input format, what outputs are available?* — including the cross-category
cases (video to audio, video to stills, image to PDF) and a per-format table for
document conversions, which are not a uniform matrix.

---

## Running

```bash
flutter pub get
flutter run -d linux      # or -d macos / -d windows
```

Desktop only. The window uses custom chrome (hidden native title bar) with a
900x620 minimum size.

## Tests

```bash
flutter test
```

64 tests covering:

- **`format_catalog_test.dart`** — the conversion matrix: no no-op conversions,
  no read-only formats offered as outputs, every readable format has a target,
  every default is a valid pair.
- **`mock_conversion_service_test.dart`** — engine contract: lifecycle, monotonic
  progress, cancellation of queued and running jobs, typed failures, the
  concurrency limit and resizing it at runtime.
- **`providers_test.dart`** — controllers over real temp files: staging and
  de-duplication, the common-format intersection, output-path resolution under
  each overwrite policy, queue transitions, retry, history recording and
  retention.
- **`app_flow_test.dart`** — the whole UI flow end to end: stage files, choose a
  format, configure settings, commit to the queue, convert, observe progress,
  reach history. Plus failure and cancellation paths, and a check that no screen
  overflows at the minimum window size.

Note on timing: the simulated engine is driven entirely by timers rather than a
wall clock, so it behaves identically under the widget tests' virtual clock.
Real work (filesystem, engine start-up) must be wrapped in
`WidgetTester.runAsync` — see the harness at the top of `app_flow_test.dart`.

## Simulation hooks

While the engine is mocked, filenames drive deterministic behaviour, which is
what makes the failure and cancellation paths testable by hand:

- a name containing `fail` always fails, with engine diagnostics and an exit code
- a name containing `slow` takes much longer
- otherwise a small deterministic chance of failure, seeded from the path

No files are written during Stage 1.
