import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../models/job_status.dart';

/// Colour pairing for a job status, resolved from the active palette.
({Color foreground, Color background}) statusColors(
  AppPalette p,
  JobStatus status,
) {
  return switch (status) {
    JobStatus.queued => (
      foreground: p.textSecondary,
      background: p.surfaceSunken,
    ),
    JobStatus.running => (foreground: p.info, background: p.infoSubtle),
    JobStatus.completed => (foreground: p.success, background: p.successSubtle),
    JobStatus.failed => (foreground: p.error, background: p.errorSubtle),
    JobStatus.cancelled => (foreground: p.warning, background: p.warningSubtle),
  };
}

/// Status pill with an icon; the running state animates so an in-progress job is
/// obvious at a glance in a long list.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final JobStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ({Color foreground, Color background}) c = statusColors(
      context.palette,
      status,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md - 2,
        vertical: compact ? 3 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (status == JobStatus.running)
            _Spinner(color: c.foreground, size: compact ? 10 : 12)
          else
            Icon(status.icon, size: compact ? 12 : 13, color: c.foreground),
          SizedBox(width: compact ? AppSpacing.xs + 1 : AppSpacing.sm - 2),
          // Flexible so the pill degrades to an ellipsis in a tight column
          // rather than overflowing its slot.
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact ? context.text.labelSmall : context.text.labelMedium)
                      ?.copyWith(
                        color: c.foreground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.autorenew_rounded,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}
