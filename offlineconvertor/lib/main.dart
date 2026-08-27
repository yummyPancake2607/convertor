import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app.dart';
import 'providers/conversion_flow_provider.dart';
import 'services/conversion_service.dart';
import 'services/file_system_service.dart';
import 'services/mock_conversion_service.dart';

/// Application entry point and composition root.
///
/// Every dependency is constructed here and injected downwards. That is what
/// makes Stage 2 a one-line change: replacing [MockConversionService] with the
/// FFI-backed service is a single substitution in [_buildConversionService], and
/// nothing in the provider, screen or widgets refers to the concrete type.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge with transparent system bars; the screen uses SafeArea so
  // content never sits under the status or navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  final ConversionService conversionService = _buildConversionService();
  final FileSystemService fileSystem = FileSystemService();

  // Two at a time by default: enough to keep the device busy without making a
  // phone thermally throttle mid-batch.
  await conversionService.initialize(maxConcurrentJobs: 2);

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ConversionService>.value(value: conversionService),
        Provider<FileSystemService>.value(value: fileSystem),
        ChangeNotifierProvider<ConversionFlowProvider>(
          create: (_) => ConversionFlowProvider(
            conversionService: conversionService,
            fileSystem: fileSystem,
          ),
        ),
      ],
      child: const ConvertorApp(),
    ),
  );
}

/// Stage 1 uses the simulated engine.
///
/// Stage 2 replaces the body of this function with:
///
/// ```dart
/// return CppFfiConversionService();
/// ```
///
/// No other file needs to change.
ConversionService _buildConversionService() => MockConversionService();
