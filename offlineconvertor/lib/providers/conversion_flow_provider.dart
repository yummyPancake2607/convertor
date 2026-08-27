import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/format_catalog.dart';
import '../core/utils/path_utils.dart';
import '../models/conversion_job.dart';
import '../models/conversion_request.dart';
import '../models/conversion_settings.dart';
import '../models/file_format.dart';
import '../models/file_info.dart';
import '../models/job_progress_update.dart';
import '../models/job_status.dart';
import '../models/media_type.dart';
import '../services/conversion_service.dart';
import '../services/file_system_service.dart';

/// Where the user is in the one-screen flow.
enum FlowStage {
  /// Pick a category: video, audio or documents.
  chooseCategory,

  /// Files are staged; pick the output format and start.
  configure,

  /// Conversions are running.
  converting,

  /// Everything finished; results can be saved.
  results,
}

/// A file staged for conversion.
class StagedFile {
  const StagedFile({required this.id, required this.info});

  final String id;
  final FileInfo info;

  String get name => info.name;
  int get sizeBytes => info.sizeBytes;
  bool get isSupported => info.isSupported && !info.probeFailed;

  /// Why this file cannot be converted, for the inline warning.
  String? get problem {
    if (info.probeFailed) return 'File could not be read';
    if (!info.isSupported) {
      final String ext = info.extension;
      return ext.isEmpty ? 'Unrecognised file type' : '.$ext is not supported';
    }
    return null;
  }
}

/// The single controller behind the whole application.
///
/// It owns the flow state (which category, which files, which target format),
/// drives the [ConversionService], and folds engine updates back into a job
/// list. The UI reads from here and calls commands; it never talks to the engine
/// directly, which is what keeps the Stage 2 swap to the native engine confined
/// to [ConversionService].
class ConversionFlowProvider extends ChangeNotifier {
  ConversionFlowProvider({
    required ConversionService conversionService,
    required FileSystemService fileSystem,
  }) : _service = conversionService,
       _fileSystem = fileSystem {
    _subscription = _service.updates.listen(_onUpdate);
  }

  final ConversionService _service;
  final FileSystemService _fileSystem;

  static const Uuid _uuid = Uuid();

  late final StreamSubscription<JobProgressUpdate> _subscription;

  FlowStage _stage = FlowStage.chooseCategory;
  MediaType? _category;
  final List<StagedFile> _files = <StagedFile>[];
  FileFormat? _outputFormat;

  /// Engine options. There is no settings screen, so these stay at their
  /// defaults; the engine still receives them, so adding a settings step later
  /// needs no change below this line.
  final ConversionSettings _settings = const ConversionSettings();

  final List<ConversionJob> _jobs = <ConversionJob>[];

  bool _isPicking = false;
  String? _error;

  // ---------------------------------------------------------------------------
  // Read API
  // ---------------------------------------------------------------------------

  FlowStage get stage => _stage;
  MediaType? get category => _category;
  List<StagedFile> get files => List<StagedFile>.unmodifiable(_files);
  FileFormat? get outputFormat => _outputFormat;
  List<ConversionJob> get jobs => List<ConversionJob>.unmodifiable(_jobs);
  bool get isPicking => _isPicking;
  String? get error => _error;

  int get fileCount => _files.length;
  bool get hasFiles => _files.isNotEmpty;

  List<StagedFile> get convertibleFiles =>
      _files.where((StagedFile f) => f.isSupported).toList();

  List<StagedFile> get problemFiles =>
      _files.where((StagedFile f) => !f.isSupported).toList();

  int get totalInputBytes =>
      _files.fold<int>(0, (int sum, StagedFile f) => sum + f.sizeBytes);

  bool get canConvert => convertibleFiles.isNotEmpty && _outputFormat != null;

  /// Output formats offered for the chosen category.
  ///
  /// Taken from the staged files so the list is exactly what the engine can
  /// produce from all of them; falls back to the category's own targets before
  /// any file is staged.
  List<FileFormat> get availableFormats {
    final List<StagedFile> usable = convertibleFiles;
    if (usable.isEmpty) {
      final MediaType? c = _category;
      if (c == null) return const <FileFormat>[];
      final List<FileFormat> readable = FormatCatalog.byMediaType(
        c,
      ).where((FileFormat f) => f.canRead).toList();
      if (readable.isEmpty) return const <FileFormat>[];
      return FormatCatalog.outputsFor(readable.first);
    }

    Set<FileFormat> common = FormatCatalog.outputsFor(
      usable.first.info.format!,
    ).toSet();
    for (final StagedFile f in usable.skip(1)) {
      common = common.intersection(
        FormatCatalog.outputsFor(f.info.format!).toSet(),
      );
    }
    return FormatCatalog.all.where(common.contains).toList();
  }

  // --- Progress ---------------------------------------------------------------

  int get runningCount =>
      _jobs.where((ConversionJob j) => j.status == JobStatus.running).length;
  int get completedCount =>
      _jobs.where((ConversionJob j) => j.status == JobStatus.completed).length;
  int get failedCount =>
      _jobs.where((ConversionJob j) => j.status == JobStatus.failed).length;
  int get cancelledCount =>
      _jobs.where((ConversionJob j) => j.status == JobStatus.cancelled).length;

  bool get isConverting =>
      _jobs.any((ConversionJob j) => !j.status.isTerminal);

  /// Overall progress across the batch, 0.0-1.0.
  double get overallProgress {
    if (_jobs.isEmpty) return 0;
    final double sum = _jobs.fold<double>(
      0,
      (double s, ConversionJob j) => s + (j.status.isTerminal ? 1.0 : j.progress),
    );
    return sum / _jobs.length;
  }

  List<ConversionJob> get successfulJobs =>
      _jobs.where((ConversionJob j) => j.status == JobStatus.completed).toList();

  bool get hasSavableResults => successfulJobs.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Chooses a category and immediately opens the system picker.
  ///
  /// One tap to reach the picker is the whole point of the category cards, so
  /// selecting a category without picking files is not a state worth having.
  Future<void> chooseCategory(MediaType category) async {
    _category = category;
    _error = null;
    notifyListeners();

    final int added = await pickFiles();
    if (added == 0 && _files.isEmpty) {
      // The picker was dismissed with nothing chosen: stay on the home screen.
      _category = null;
      notifyListeners();
      return;
    }
    _stage = FlowStage.configure;
    notifyListeners();
  }

  /// Opens the picker and stages whatever is selected. Returns how many were
  /// added.
  Future<int> pickFiles() async {
    final MediaType? category = _category;
    if (category == null) return 0;

    _isPicking = true;
    _error = null;
    notifyListeners();

    int added = 0;
    try {
      final List<String> paths = await _fileSystem.pickFilesFor(category);
      final Set<String> existing =
          _files.map((StagedFile f) => f.info.path).toSet();
      final List<String> fresh = paths
          .where((String p) => p.isNotEmpty && !existing.contains(p))
          .toSet()
          .toList();

      if (fresh.isNotEmpty) {
        final List<FileInfo> probed = await Future.wait(
          fresh.map(_service.probe),
        );
        for (final FileInfo info in probed) {
          _files.add(StagedFile(id: _uuid.v4(), info: info));
        }
        added = fresh.length;
        _ensureFormatIsValid();
      }
    } catch (e) {
      _error = 'Could not read the selected files: $e';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
    return added;
  }

  void removeFile(String id) {
    _files.removeWhere((StagedFile f) => f.id == id);
    _ensureFormatIsValid();
    if (_files.isEmpty) {
      _stage = FlowStage.chooseCategory;
      _category = null;
    }
    notifyListeners();
  }

  void setOutputFormat(FileFormat format) {
    _outputFormat = format;
    notifyListeners();
  }

  /// Keeps the chosen target valid as the file list changes.
  void _ensureFormatIsValid() {
    final List<FileFormat> options = availableFormats;
    if (options.isEmpty) {
      _outputFormat = null;
      return;
    }
    if (_outputFormat != null && options.contains(_outputFormat)) return;

    final List<StagedFile> usable = convertibleFiles;
    if (usable.isNotEmpty) {
      final FileFormat preferred = FormatCatalog.defaultOutputFor(
        usable.first.info.format!,
      );
      _outputFormat = options.contains(preferred) ? preferred : options.first;
    } else {
      _outputFormat = options.first;
    }
  }

  /// Creates and starts a job per convertible file.
  Future<void> startConversion() async {
    final FileFormat? format = _outputFormat;
    if (format == null) return;

    final List<StagedFile> usable = convertibleFiles;
    if (usable.isEmpty) return;

    _stage = FlowStage.converting;
    _jobs.clear();
    _error = null;
    notifyListeners();

    // Previous results are cleared so a new batch starts from a clean folder.
    await _fileSystem.clearWorkingOutputs();
    final String outputDirectory = await _fileSystem.workingOutputDirectory();

    for (final StagedFile file in usable) {
      final String desired = PathUtils.buildOutputPath(
        inputPath: file.info.path,
        outputExtension: format.extension,
        outputDirectory: outputDirectory,
      );
      final ConversionRequest request = ConversionRequest(
        input: file.info,
        outputFormat: format,
        outputPath: await _fileSystem.uniqueOutputPath(desired),
        settings: _settings,
      );

      final String id = await _service.createJob(request);
      _jobs.add(
        ConversionJob(id: id, request: request, createdAt: DateTime.now()),
      );
    }
    notifyListeners();

    for (final ConversionJob job in _jobs) {
      await _service.startJob(job.id);
    }
  }

  /// Stops everything still running or queued.
  Future<void> cancelAll() async {
    for (final ConversionJob job in _jobs) {
      if (job.status.canCancel) await _service.cancelJob(job.id);
    }
  }

  Future<void> retryFailed() async {
    final List<ConversionJob> failed =
        _jobs.where((ConversionJob j) => j.status.canRetry).toList();
    if (failed.isEmpty) return;

    _stage = FlowStage.converting;
    notifyListeners();

    for (final ConversionJob job in failed) {
      final int index = _jobs.indexWhere((ConversionJob j) => j.id == job.id);
      await _service.disposeJob(job.id);
      final String newId = await _service.createJob(job.request);
      _jobs[index] = ConversionJob(
        id: newId,
        request: job.request,
        createdAt: job.createdAt,
        attempt: job.attempt + 1,
      );
      await _service.startJob(newId);
    }
    notifyListeners();
  }

  /// Saves one completed job's output to a location the user chooses.
  Future<SaveOutcome> saveResult(ConversionJob job) {
    return _fileSystem.saveFileToUserLocation(
      sourcePath: job.outputPath,
      suggestedName: job.outputFileName,
    );
  }

  /// Returns to the start, clearing files and results.
  Future<void> reset() async {
    for (final ConversionJob job in _jobs) {
      await _service.disposeJob(job.id);
    }
    _jobs.clear();
    _files.clear();
    _outputFormat = null;
    _category = null;
    _error = null;
    _stage = FlowStage.chooseCategory;
    notifyListeners();
  }

  /// Steps back one stage.
  Future<void> back() async {
    switch (_stage) {
      case FlowStage.configure:
        await reset();
      case FlowStage.results:
        await reset();
      case FlowStage.converting:
      case FlowStage.chooseCategory:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Engine updates
  // ---------------------------------------------------------------------------

  void _onUpdate(JobProgressUpdate update) {
    final int index = _jobs.indexWhere(
      (ConversionJob j) => j.id == update.jobId,
    );
    if (index == -1) return;

    _jobs[index] = _jobs[index].applyUpdate(update);

    // The batch is finished when nothing is left running or queued.
    if (_stage == FlowStage.converting && !isConverting) {
      _stage = FlowStage.results;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
