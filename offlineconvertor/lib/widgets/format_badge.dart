import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../models/file_format.dart';
import '../models/media_type.dart';

/// The accent colour for a media category.
Color mediaTypeColor(AppPalette p, MediaType type) => switch (type) {
  MediaType.video => p.video,
  MediaType.audio => p.audio,
  MediaType.image => p.image,
  MediaType.document => p.document,
  MediaType.unknown => p.neutral,
};

/// Monospace-ish uppercase format tag, tinted by media category.
class FormatBadge extends StatelessWidget {
  const FormatBadge({
    super.key,
    required this.label,
    required this.mediaType,
    this.filled = false,
  });

  FormatBadge.format(FileFormat format, {super.key, this.filled = false})
    : label = format.badge,
      mediaType = format.mediaType;

  final String label;
  final MediaType mediaType;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color accent = mediaTypeColor(context.palette, mediaType);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: filled ? accent : accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.xs + 1),
        border: filled
            ? null
            : Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: filled ? Colors.white : accent,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// "MP4 -> MP3" pair, used on job and history rows.
class ConversionArrow extends StatelessWidget {
  const ConversionArrow({
    super.key,
    required this.from,
    required this.fromType,
    required this.to,
    required this.toType,
  });

  final String from;
  final MediaType fromType;
  final String to;
  final MediaType toType;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FormatBadge(label: from, mediaType: fromType),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 1),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: context.palette.textTertiary,
          ),
        ),
        FormatBadge(label: to, mediaType: toType, filled: true),
      ],
    );
  }
}

/// Square tinted icon tile for a media category.
class MediaTypeTile extends StatelessWidget {
  const MediaTypeTile({
    super.key,
    required this.mediaType,
    this.size = 36,
    this.iconSize = 18,
  });

  final MediaType mediaType;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Color accent = mediaTypeColor(context.palette, mediaType);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(mediaType.icon, size: iconSize, color: accent),
    );
  }
}
