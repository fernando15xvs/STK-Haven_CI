import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';

/// Pure policies for the Home surface. They never mutate session history.
class HomeDashboardSessionPolicy {
  const HomeDashboardSessionPolicy._();

  /// Do not show the exact same workout as both "Finalizado hoy" and
  /// "Último entrenamiento". Do not relabel an older workout as "último".
  static WorkoutSession? recentWorkout({
    required List<WorkoutSession> history,
    required WorkoutSession? completedToday,
  }) {
    if (history.isEmpty) return null;
    final latest = history.first;
    return latest.id == completedToday?.id ? null : latest;
  }

  /// Count fully completed effective sessions in this legacy program only.
  /// Partial, warm-up-only, foreign and pre-start snapshots never qualify.
  static int completedProgramSessions({
    required Iterable<WorkoutSession> history,
    required ActiveProgramState activeProgram,
    DateTime? now,
  }) {
    final asOf = now ?? DateTime.now();
    final routineIds = activeProgram.generatedRoutineIds.toSet();
    final completedIds = <String>{};
    for (final session in history) {
      if (!session.startedAt.isBefore(activeProgram.startedAt) &&
          !session.finishedAt.isBefore(session.startedAt) &&
          !session.finishedAt.isAfter(asOf) &&
          routineIds.contains(session.routineId) &&
          TodaysWorkoutStatus.isComplete(session)) {
        completedIds.add(session.id);
      }
    }
    return completedIds.length;
  }
}
