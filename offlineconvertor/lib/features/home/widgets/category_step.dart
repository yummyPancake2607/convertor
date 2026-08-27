import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/format_catalog.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/file_format.dart';
import '../../../models/media_type.dart';
import '../../../providers/conversion_flow_provider.dart';
import '../../../widgets/format_badge.dart';

/// Step 1: choose what kind of file to convert.
///
/// Tapping a card opens the system picker straight away, so getting from launch
/// to choosing files is a single tap.
class CategoryStep extends StatelessWidget {
  const CategoryStep({super.key});

  /// The categories offered on the home screen.
  static const List<MediaType> categories = <MediaType>[
    MediaType.video,
    MediaType.audio,
    MediaType.document,
  ];

  @override
  Widget build(BuildContext context) {
    final ConversionFlowProvider flow = context.watch<ConversionFlowProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text('What do you want to convert?', style: context.text.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pick a type, choose your files, and convert.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final MediaType category in categories) ...<Widget>[
          _CategoryCard(
            category: category,
            busy: flow.isPicking && flow.category == category,
            onTap: flow.isPicking ? null : () => flow.chooseCategory(category),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.wifi_off_rounded,
              size: 14,
              color: context.palette.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Everything runs on your device',
              style: context.text.bodySmall?.copyWith(
                color: context.palette.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
    required this.busy,
  });

  final MediaType category;
  final VoidCallback? onTap;
  final bool busy;

  /// A few example formats, so the card says what it actually accepts.
  String get _examples {
    final List<FileFormat> formats = FormatCatalog.byMediaType(category)
        .where((FileFormat f) => f.canRead)
        .take(5)
        .toList();
    return formats.map((FileFormat f) => f.badge).join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = mediaTypeColor(context.palette, category);

    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accent,
                        ),
                      )
                    : Icon(category.icon, size: 26, color: accent),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      category.pluralLabel,
                      style: context.text.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _examples,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textTertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: context.palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
