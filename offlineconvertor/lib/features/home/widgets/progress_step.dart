import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/conversion_job.dart';
import '../../../models/job_status.dart';
import '../../../providers/conversion_flow_provider.dart';
import '../../../widgets/format_badge.dart';
import '../../../widgets/progress_display.dart';

/// Step 3: conversion in progress.
///
/// A single headline progress figure for the batch, plus a per-file bar so it is
/// clear which file is being worked on and which are still waiting.
class ProgressStep extends StatelessWidget {
  const ProgressStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ConversionFlowProvider flow = context.watch<ConversionFlowProvider>();
    final List<ConversionJob> jobs = flow.jobs;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _OverallCard(flow: flow),
              const SizedBox(height: AppSpacing.xl),
              for (final ConversionJob job in jobs)
                _JobRow(key: ValueKey<String>(job.id), job: job),
            ],
          ),
        ),
        _CancelBar(flow: flow),
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.flow});

  final ConversionFlowProvider flow;

  @override
  Widget build(BuildContext context) {
    final int done = flow.completedCount + flow.failedCount + flow.cancelledCount;
    final int total = flow.jobs.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 92,
                  height: 92,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: flow.overallProgress),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    builder: (BuildContext context, double value, Widget? _) {
                      return CircularProgressIndicator(
                        value: value == 0 ? null : value,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.palette.surfaceSunken,
                        color: context.palette.accent,
                      );
                    },
                  ),
                ),
                Text(
                  Formatters.percent(flow.overallProgress),
                  style: context.text.headlineMedium?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Converting', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$done of $total finished',
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({super.key, required this.job});

  final ConversionJob job;

  @override
  Widget build(BuildContext context) {
    final bool waiting = job.status == JobStatus.queued;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    job.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: waiting
                          ? context.palette.textSecondary
                          : context.palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FormatBadge.format(job.outputFormat, filled: !waiting),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            JobProgressBar(
              progress: job.progress,
              status: job.status,
              height: 5,
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    switch (job.status) {
                      JobStatus.queued => 'Waiting',
                      JobStatus.running => job.stage ?? 'Working',
                      JobStatus.completed => 'Done',
                      JobStatus.failed =>
                        job.error?.code.label ?? 'Failed',
                      JobStatus.cancelled => 'Cancelled',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: job.status == JobStatus.failed
                          ? context.palette.error
                          : context.palette.textTertiary,
                    ),
                  ),
                ),
                if (job.status == JobStatus.running && job.eta != null)
                  Text(
                    '${Formatters.shortDuration(job.eta!)} left',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textTertiary,
                    ),
                  )
                else if (!job.status.isTerminal)
                  Text(
                    Formatters.percent(job.progress),
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textTertiary,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.flow});

  final ConversionFlowProvider flow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.sidebarBackground,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md + context.bottomInset,
        ),
        child: SizedBox(
          height: AppSizes.controlHeight,
          child: OutlinedButton.icon(
            onPressed: flow.isConverting ? flow.cancelAll : null,
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text('Cancel'),
          ),
        ),
      ),
    );
  }
}
