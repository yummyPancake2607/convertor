import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/conversion_job.dart';
import '../../../models/job_status.dart';
import '../../../providers/conversion_flow_provider.dart';
import '../../../services/conversion_service.dart';
import '../../../services/file_system_service.dart';
import '../../../widgets/progress_display.dart';
import '../../../widgets/status_badge.dart';

/// Step 4: results, and choosing where to keep them.
///
/// Conversions land in the app's own cache first. Saving is a separate,
/// explicit step because that is the only way to write anywhere else on modern
/// Android: the system's "create document" dialog does the write, so the user
/// picks the destination and no storage permission is needed.
class ResultsStep extends StatefulWidget {
  const ResultsStep({super.key});

  @override
  State<ResultsStep> createState() => _ResultsStepState();
}

class _ResultsStepState extends State<ResultsStep> {
  /// Jobs whose output the user has already saved somewhere.
  final Set<String> _saved = <String>{};
  bool _savingAll = false;

  Future<void> _save(ConversionJob job) async {
    final ConversionFlowProvider flow = context.read<ConversionFlowProvider>();
    final SaveOutcome outcome = await flow.saveResult(job);
    if (!mounted) return;

    switch (outcome) {
      case SaveOutcome.saved:
        setState(() => _saved.add(job.id));
        context.showToast(
          'Saved ${job.outputFileName}',
          icon: Icons.check_circle_outline_rounded,
          accent: context.palette.success,
        );
      case SaveOutcome.cancelled:
        break;
      case SaveOutcome.sourceMissing:
        context.showToast(
          'The converted file is no longer available. Convert again.',
          icon: Icons.error_outline_rounded,
          accent: context.palette.warning,
        );
      case SaveOutcome.failed:
        context.showToast(
          'Could not save that file',
          icon: Icons.error_outline_rounded,
          accent: context.palette.error,
        );
    }
  }

  /// Saves each result in turn. The system asks for a destination per file,
  /// which is what its create-document flow provides.
  Future<void> _saveAll(List<ConversionJob> jobs) async {
    setState(() => _savingAll = true);
    for (final ConversionJob job in jobs) {
      if (_saved.contains(job.id)) continue;
      final SaveOutcome outcome =
          await context.read<ConversionFlowProvider>().saveResult(job);
      if (!mounted) return;
      if (outcome == SaveOutcome.saved) {
        setState(() => _saved.add(job.id));
      } else if (outcome == SaveOutcome.cancelled) {
        // Dismissing the dialog means "stop", not "skip this one".
        break;
      }
    }
    if (mounted) setState(() => _savingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    final ConversionFlowProvider flow = context.watch<ConversionFlowProvider>();
    final List<ConversionJob> jobs = flow.jobs;
    final List<ConversionJob> successful = flow.successfulJobs;
    final bool simulated =
        !context.read<ConversionService>().engineInfo.isNative;

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
              _Summary(flow: flow),
              if (simulated) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const _SimulatedNotice(),
              ],
              const SizedBox(height: AppSpacing.xl),
              for (final ConversionJob job in jobs)
                _ResultRow(
                  key: ValueKey<String>(job.id),
                  job: job,
                  saved: _saved.contains(job.id),
                  onSave: () => _save(job),
                ),
              if (flow.failedCount > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: flow.retryFailed,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Retry ${flow.failedCount} failed'),
                ),
              ],
            ],
          ),
        ),
        _SaveBar(
          successful: successful,
          savedCount: _saved.length,
          busy: _savingAll,
          onSaveAll: () => _saveAll(successful),
          onDone: flow.reset,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.flow});

  final ConversionFlowProvider flow;

  @override
  Widget build(BuildContext context) {
    final bool allGood = flow.failedCount == 0 && flow.cancelledCount == 0;
    final Color accent =
        allGood ? context.palette.success : context.palette.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Icon(
              allGood ? Icons.check_rounded : Icons.warning_amber_rounded,
              size: 28,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            allGood
                ? '${flow.completedCount} file'
                      '${flow.completedCount == 1 ? '' : 's'} converted'
                : '${flow.completedCount} converted, '
                      '${flow.failedCount + flow.cancelledCount} did not finish',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose where to keep them.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SimulatedNotice extends StatelessWidget {
  const _SimulatedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.science_outlined,
            size: 17,
            color: context.palette.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The conversion engine is not connected yet, so these files are '
              'placeholders rather than real converted media.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.job,
    required this.saved,
    required this.onSave,
  });

  final ConversionJob job;
  final bool saved;
  final VoidCallback onSave;

  Future<void> _open(BuildContext context) async {
    final OpenFileOutcome outcome =
        await context.read<FileSystemService>().openFile(job.outputPath);
    if (!outcome.isSuccess && context.mounted) {
      context.showToast(
        outcome.message,
        icon: Icons.error_outline_rounded,
        accent: context.palette.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ok = job.status == JobStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                    ok ? job.outputFileName : job.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(status: job.status, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (ok)
              Row(
                children: <Widget>[
                  Text(
                    '${Formatters.fileSize(job.inputSizeBytes)} → '
                    '${Formatters.fileSize(job.outputSizeBytes ?? 0)}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (job.sizeDeltaFraction != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    SizeDeltaLabel(fraction: job.sizeDeltaFraction!),
                  ],
                ],
              )
            else
              Text(
                job.error?.message ?? job.status.label,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.error,
                ),
              ),
            if (ok) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: saved
                        ? Row(
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: context.palette.success,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Saved',
                                style: context.text.labelLarge?.copyWith(
                                  color: context.palette.success,
                                ),
                              ),
                            ],
                          )
                        : OutlinedButton.icon(
                            onPressed: onSave,
                            icon: const Icon(
                              Icons.save_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Save'),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _open(context),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.successful,
    required this.savedCount,
    required this.busy,
    required this.onSaveAll,
    required this.onDone,
  });

  final List<ConversionJob> successful;
  final int savedCount;
  final bool busy;
  final VoidCallback onSaveAll;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final int remaining = successful.length - savedCount;

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
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onDone,
                child: const Text('Done'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: AppSizes.controlHeight,
                child: FilledButton.icon(
                  onPressed: remaining <= 0 || busy ? null : onSaveAll,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded, size: 20),
                  label: Text(
                    remaining <= 0
                        ? 'All saved'
                        : successful.length == 1
                              ? 'Save file'
                              : 'Save $remaining files',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
