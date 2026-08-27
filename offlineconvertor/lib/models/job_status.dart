import 'package:flutter/material.dart';

/// Lifecycle state of a conversion job.
///
/// Deliberately identical to the C++ engine's `JobStatus` enum so the FFI layer
/// can map it with a plain integer cast.
enum JobStatus {
  queued,
  running,
  completed,
  failed,
  cancelled;

  String get label => switch (this) {
    JobStatus.queued => 'Queued',
    JobStatus.running => 'Converting',
    JobStatus.completed => 'Completed',
    JobStatus.failed => 'Failed',
    JobStatus.cancelled => 'Cancelled',
  };

  IconData get icon => switch (this) {
    JobStatus.queued => Icons.schedule_rounded,
    JobStatus.running => Icons.autorenew_rounded,
    JobStatus.completed => Icons.check_circle_outline_rounded,
    JobStatus.failed => Icons.error_outline_rounded,
    JobStatus.cancelled => Icons.block_rounded,
  };

  /// The job has finished and will not change again without a retry.
  bool get isTerminal => switch (this) {
    JobStatus.completed || JobStatus.failed || JobStatus.cancelled => true,
    _ => false,
  };

  bool get isActive => this == JobStatus.running;

  /// The job can be retried from a terminal state.
  bool get canRetry => this == JobStatus.failed || this == JobStatus.cancelled;

  bool get canStart => this == JobStatus.queued;

  bool get canCancel => this == JobStatus.queued || this == JobStatus.running;

  String get id => name;

  static JobStatus fromId(String? id) => JobStatus.values.firstWhere(
    (JobStatus s) => s.name == id,
    orElse: () => JobStatus.queued,
  );
}
