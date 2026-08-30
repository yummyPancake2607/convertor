import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/conversion_flow_provider.dart';
import 'widgets/category_step.dart';
import 'widgets/configure_step.dart';
import 'widgets/progress_step.dart';
import 'widgets/results_step.dart';

/// The application's only screen.
///
/// One screen with four steps rather than several pages: pick a type, pick
/// files, watch it convert, choose where to save. The step comes from
/// [ConversionFlowProvider.stage], so there is no navigation stack to keep in
/// sync with the conversion state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ConversionFlowProvider flow = context.watch<ConversionFlowProvider>();
    final FlowStage stage = flow.stage;

    // Android's back gesture should step back through the flow rather than
    // closing the app, whenever there is somewhere to step back to.
    final bool canGoBack =
        stage == FlowStage.configure || stage == FlowStage.results;

    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && canGoBack) flow.back();
      },
      child: Scaffold(
        backgroundColor: context.palette.windowBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Start over',
                  onPressed: flow.back,
                )
              : null,
          title: Row(
            children: <Widget>[
              if (!canGoBack) ...<Widget>[
                const _BrandMark(),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  _titleFor(stage, flow),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: AppConstants.mediumAnimation,
            // Steps are full-height layouts with their own sticky bars, so they
            // must not be stacked centred during the cross-fade.
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, ?current],
            ),
            child: switch (stage) {
              FlowStage.chooseCategory => const CategoryStep(
                key: ValueKey<String>('category'),
              ),
              FlowStage.configure => const ConfigureStep(
                key: ValueKey<String>('configure'),
              ),
              FlowStage.converting => const ProgressStep(
                key: ValueKey<String>('progress'),
              ),
              FlowStage.results => const ResultsStep(
                key: ValueKey<String>('results'),
              ),
            },
          ),
        ),
      ),
    );
  }

  static String _titleFor(FlowStage stage, ConversionFlowProvider flow) {
    return switch (stage) {
      FlowStage.chooseCategory => AppConstants.appName,
      FlowStage.configure => flow.category?.pluralLabel ?? 'Files',
      FlowStage.converting => 'Converting',
      FlowStage.results => 'Finished',
    };
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.asset(
        'assests/logo.png',
        width: 30,
        height: 30,
        fit: BoxFit.cover,
      ),
    );
  }
}
