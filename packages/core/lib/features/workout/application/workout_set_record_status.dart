import 'package:core/domain/models/workout_session.dart';

/// User-visible state of a recorded set. This is deliberately NOT serialized:
/// legacy WorkoutSet only contains `completed` and cannot prove intent.
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
  /// unless a caller can provide real, explicit evidence to the contrary.
  ///
  /// This policy does not guess from reps, weight, RIR, session completion,
  /// remaining planned sets or an interrupted workout.
  static WorkoutSetRecordStatus fromSet(
    WorkoutSet set, {
    WorkoutSetOutcomeEvidence? recordedOutcome,
  }) {
    if (set.completed) return WorkoutSetRecordStatus.completed;
    return switch (recordedOutcome) {
      WorkoutSetOutcomeEvidence.skipped => WorkoutSetRecordStatus.skipped,
      WorkoutSetOutcomeEvidence.failed => WorkoutSetRecordStatus.failed,
      null => WorkoutSetRecordStatus.pending,
    };
  }
}
