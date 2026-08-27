import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/path_utils.dart';
import '../models/media_type.dart';

/// Result of asking the OS to open a file.
enum OpenFileOutcome {
  opened,
  missing,
  noHandler,
  failed;

  String get message => switch (this) {
    OpenFileOutcome.opened => 'Opened',
    OpenFileOutcome.missing => 'That file is no longer on the device',
    OpenFileOutcome.noHandler => 'No app on this device can open that file',
    OpenFileOutcome.failed => 'Could not open that file',
  };

  bool get isSuccess => this == OpenFileOutcome.opened;
}

/// Result of saving a converted file to a user-chosen location.
enum SaveOutcome {
  saved,
  cancelled,
  sourceMissing,
  failed;

  bool get isSuccess => this == SaveOutcome.saved;
}

/// All filesystem and OS interaction, in one place.
///
/// Android's storage rules are the reason this matters: a picked file is a
/// cached copy, a raw `file://` URI cannot be handed to another app, and an app
/// cannot freely write outside its own directories. Those rules live here rather
/// than being rediscovered in each screen.
class FileSystemService {
  /// Opens the system picker for one media category.
  ///
  /// Android's picker filters by MIME type, so video and audio use the system's
  /// own categories. Documents have no single MIME family, so everything is
  /// offered and the caller filters afterwards by extension.
  Future<List<String>> pickFilesFor(MediaType category) async {
    final FileType type = switch (category) {
      MediaType.video => FileType.video,
      MediaType.audio => FileType.audio,
      MediaType.image => FileType.image,
      MediaType.document || MediaType.unknown => FileType.any,
    };

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      dialogTitle: 'Select ${category.pluralLabel.toLowerCase()}',
    );
    if (result == null) return const <String>[];
    return result.paths.whereType<String>().toList();
  }

  /// Hands a converted file to the system so the user can choose where it goes.
  ///
  /// This uses the Storage Access Framework's "create document" flow: the system
  /// writes the bytes to wherever the user picks. It is the only way to save
  /// outside the app's own folders on modern Android without asking for broad
  /// storage permission, and it needs no permission at all.
  Future<SaveOutcome> saveFileToUserLocation({
    required String sourcePath,
    required String suggestedName,
  }) async {
    final File source = File(sourcePath);
    if (!await source.exists()) return SaveOutcome.sourceMissing;

    try {
      final Uint8List bytes = await source.readAsBytes();
      final String? destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $suggestedName',
        fileName: suggestedName,
        bytes: bytes,
      );
      return destination == null ? SaveOutcome.cancelled : SaveOutcome.saved;
    } on FileSystemException {
      return SaveOutcome.failed;
    } catch (_) {
      return SaveOutcome.failed;
    }
  }

  /// Hands a file to whichever installed app can display it.
  Future<OpenFileOutcome> openFile(String path) async {
    if (!await File(path).exists()) return OpenFileOutcome.missing;
    try {
      final OpenResult result = await OpenFilex.open(path);
      return switch (result.type) {
        ResultType.done => OpenFileOutcome.opened,
        ResultType.noAppToOpen => OpenFileOutcome.noHandler,
        ResultType.fileNotFound => OpenFileOutcome.missing,
        _ => OpenFileOutcome.failed,
      };
    } catch (_) {
      return OpenFileOutcome.failed;
    }
  }

  /// Working directory the engine writes conversions into.
  ///
  /// Inside the app's own cache: results land here first and only reach the
  /// user's storage when they explicitly save, so a conversion never leaves
  /// files scattered around the device.
  Future<String> workingOutputDirectory() async {
    final Directory cache = await getTemporaryDirectory();
    final String path = PathUtils.join(cache.path, 'conversions');
    await ensureDirectory(path);
    return path;
  }

  Future<String> systemTemporaryDirectory() async =>
      (await getTemporaryDirectory()).path;

  Future<bool> ensureDirectory(String directory) async {
    if (directory.isEmpty) return false;
    try {
      final Directory dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> fileExists(String path) => File(path).exists();

  Future<int> fileSize(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  /// Resolves a non-colliding output path by appending `_1`, `_2`, ...
  Future<String> uniqueOutputPath(String desiredPath) async {
    if (!await File(desiredPath).exists()) return desiredPath;

    final String dir = PathUtils.directory(desiredPath);
    final String base = PathUtils.fileNameWithoutExtension(desiredPath);
    final String ext = PathUtils.extension(desiredPath);

    for (int i = 1; i < 1000; i++) {
      final String candidate = PathUtils.join(dir, '${base}_$i.$ext');
      if (!await File(candidate).exists()) return candidate;
    }
    return desiredPath;
  }

  /// Deletes everything in the working output directory.
  ///
  /// Called when the user starts a new batch, so cached results from a previous
  /// run do not accumulate.
  Future<void> clearWorkingOutputs() async {
    try {
      final Directory dir = Directory(await workingOutputDirectory());
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // A file still being read is not worth failing the flow over.
    }
  }
}
