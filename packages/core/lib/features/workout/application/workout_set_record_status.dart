import 'package:core/domain/models/workout_session.dart';

/// User-visible status; new explicit outcomes persist independently of
/// the legacy completed bit, which must never imply failure.
enum WorkoutSetRecordStatus {
  pending,
  completed,
  skipped,
  failed,
}

extension WorkoutSetRecordStatusLabel on WorkoutSetRecordStatus {
  String get label => switch (this) {
        WorkoutSetRecordStatus.pending => 'Pendiente',
        WorkoutSetRecordStatus.completed => 'Completada',
        WorkoutSetRecordStatus.skipped => 'Omitida',
        WorkoutSetRecordStatus.failed => 'Fallida',
      };
}

/// Explicit evidence of the user's intent/outcome from a future recorded
/// action. A rest timer's "Omitir" is NOT evidence of skipping a set.
enum WorkoutSetOutcomeEvidence {
  skipped,
  failed,
}

class WorkoutSetRecordStatusPolicy {
  const WorkoutSetRecordStatusPolicy._();

  /// Backward compatible. An unfinished historical set is always "Pendiente"
  /// unless an explicit action saved its outcome.
  ///
  /// This policy does not guess from reps, weight, RIR, session completion,
  /// remaining planned sets or an interrupted workout.
  static WorkoutSetRecordStatus fromSet(
    WorkoutSet set, {
    WorkoutSetOutcomeEvidence? recordedOutcome,
  }) {
    if (set.completed) return WorkoutSetRecordStatus.completed;
    final evidence = recordedOutcome ?? switch (set.recordedOutcome) {
      'skipped' => WorkoutSetOutcomeEvidence.skipped,
      'failed' => WorkoutSetOutcomeEvidence.failed,
      _ => null,
    };
    return switch (evidence) {
      WorkoutSetOutcomeEvidence.skipped => WorkoutSetRecordStatus.skipped,
      WorkoutSetOutcomeEvidence.failed => WorkoutSetRecordStatus.failed,
      null => WorkoutSetRecordStatus.pending,
    };
  }
}
