import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/job_status.dart';
import 'status_badge.dart';

/// Thin progress bar that animates between values and takes its colour from the
/// job status, so a failed job's bar reads as failed rather than just stopped.
class JobProgressBar extends StatelessWidget {
  const JobProgressBar({
    super.key,
    required this.progress,
    required this.status,
    this.height = 5,
    this.indeterminate = false,
  });

  final double progress;
  final JobStatus status;
  final double height;

  /// Used while a job is starting and the engine has not reported a fraction.
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final Color color = statusColors(context.palette, status).foreground;
    final BorderRadius radius = BorderRadius.circular(AppRadius.pill);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: indeterminate
            ? LinearProgressIndicator(
                backgroundColor: context.palette.surfaceSunken,
                color: color,
                minHeight: height,
              )
            : _AnimatedBar(
                progress: progress.clamp(0.0, 1.0),
                color: color,
                background: context.palette.surfaceSunken,
              ),
      ),
    );
  }
}

/// Glides between engine ticks instead of stepping, using Flutter's implicit
/// animation builder.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.progress,
    required this.color,
    required this.background,
  });

  final double progress;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) {
        return LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: background,
          color: color,
        );
      },
    );
  }
}

/// Stage label, percentage, speed and ETA, laid out as one line.
class ProgressMetaRow extends StatelessWidget {
  const ProgressMetaRow({
    super.key,
    required this.progress,
    this.stage,
    this.eta,
    this.speedMultiplier,
  });

  final double progress;
  final String? stage;
  final Duration? eta;
  final double? speedMultiplier;

  @override
  Widget build(BuildContext context) {
    final List<String> right = <String>[
      if (speedMultiplier != null && speedMultiplier! > 0)
        '${speedMultiplier!.toStringAsFixed(speedMultiplier! >= 10 ? 0 : 1)}x',
      if (eta != null) '${Formatters.shortDuration(eta!)} left',
    ];

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            stage ?? 'Working',
            style: context.text.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (right.isNotEmpty) ...<Widget>[
          Text(
            right.join('  ·  '),
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Text(
          Formatters.percent(progress),
          style: context.text.labelLarge?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// "-42%" / "+18%" size change label, coloured by direction.
class SizeDeltaLabel extends StatelessWidget {
  const SizeDeltaLabel({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final bool smaller = fraction < 0;
    final Color color = smaller
        ? context.palette.success
        : context.palette.textTertiary;
    final int percent = (fraction.abs() * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          smaller ? Icons.south_rounded : Icons.north_rounded,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '$percent%',
          style: context.text.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
