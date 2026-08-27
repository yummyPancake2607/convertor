import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/format_catalog.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/file_format.dart';
import '../../../models/media_type.dart';
import '../../../providers/conversion_flow_provider.dart';
import '../../../widgets/app_controls.dart';
import '../../../widgets/format_badge.dart';
import '../../../widgets/option_sheet.dart';

/// Step 2: the staged files, the target format, and the button that starts it.
class ConfigureStep extends StatelessWidget {
  const ConfigureStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ConversionFlowProvider flow = context.watch<ConversionFlowProvider>();
    final List<StagedFile> files = flow.files;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _FormatSelector(flow: flow),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${files.length} file${files.length == 1 ? '' : 's'}'
                      '  ·  ${Formatters.fileSize(flow.totalInputBytes)}',
                      style: context.text.labelLarge?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: flow.isPicking ? null : flow.pickFiles,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final StagedFile file in files)
                _FileRow(
                  key: ValueKey<String>(file.id),
                  file: file,
                  onRemove: () => flow.removeFile(file.id),
                ),
              if (flow.error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  flow.error!,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        _StartBar(flow: flow),
      ],
    );
  }
}

/// The "convert to" control. This is the one decision this step exists for, so
/// it sits at the top rather than below the file list.
class _FormatSelector extends StatelessWidget {
  const _FormatSelector({required this.flow});

  final ConversionFlowProvider flow;

  Future<void> _pick(BuildContext context) async {
    final List<FileFormat> options = flow.availableFormats;
    final Map<MediaType, List<FileFormat>> grouped =
        FormatCatalog.groupByMediaType(options);

    final FileFormat? chosen = await showOptionSheet<FileFormat>(
      context,
      title: 'Convert to',
      selected: flow.outputFormat,
      groups: <SheetGroup<FileFormat>>[
        for (final MediaType type in MediaType.values)
          if (grouped[type] != null && grouped[type]!.isNotEmpty)
            SheetGroup<FileFormat>(
              title: type.label,
              icon: type.icon,
              options: <SheetOption<FileFormat>>[
                for (final FileFormat f in grouped[type]!)
                  SheetOption<FileFormat>(
                    value: f,
                    label: f.label,
                    description: f.description.isEmpty ? null : f.description,
                    leading: FormatBadge.format(f),
                  ),
              ],
            ),
      ],
    );
    if (chosen != null) flow.setOutputFormat(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final FileFormat? format = flow.outputFormat;
    final bool usable = flow.availableFormats.isNotEmpty;

    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: usable ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: usable
                  ? context.palette.accent.withValues(alpha: 0.35)
                  : context.palette.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Convert to',
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        if (format != null) ...<Widget>[
                          FormatBadge.format(format, filled: true),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            usable
                                ? (format?.label ?? 'Choose a format')
                                : 'No shared format for these files',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 24,
                color: usable
                    ? context.palette.accent
                    : context.palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({super.key, required this.file, required this.onRemove});

  final StagedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String? problem = file.problem;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: <Widget>[
            MediaTypeTile(
              mediaType: file.info.mediaType,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: problem != null
                          ? context.palette.textSecondary
                          : context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    problem ?? _metadata(file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: problem != null
                          ? context.palette.warning
                          : context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            IconAction(
              icon: Icons.close_rounded,
              tooltip: 'Remove',
              size: 40,
              iconSize: 18,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  static String _metadata(StagedFile file) {
    final List<String> parts = <String>[Formatters.fileSize(file.sizeBytes)];
    if (file.info.duration != null) {
      parts.add(Formatters.duration(file.info.duration!));
    }
    if (file.info.dimensionsLabel != null) {
      parts.add(file.info.dimensionsLabel!);
    }
    if (file.info.pageCount != null) {
      parts.add('${file.info.pageCount} pages');
    }
    return parts.join('  ·  ');
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({required this.flow});

  final ConversionFlowProvider flow;

  @override
  Widget build(BuildContext context) {
    final int ready = flow.convertibleFiles.length;
    final int skipped = flow.problemFiles.length;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (skipped > 0) ...<Widget>[
              Text(
                '$skipped file${skipped == 1 ? '' : 's'} will be skipped',
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              height: AppSizes.controlHeight,
              child: FilledButton.icon(
                onPressed: flow.canConvert ? flow.startConversion : null,
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: Text(
                  ready == 0
                      ? 'Nothing to convert'
                      : 'Convert $ready file${ready == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
