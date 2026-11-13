import 'package:core/domain/models/workout_session.dart';

/// Dashboard should not offer to restart a completed workout on the same day.
/// Only a fully finished effective session qualifies; partial workouts stay
/// resumable and future days are allowed to show the next training session.
class TodaysWorkoutStatus {
  const TodaysWorkoutStatus._();

  static bool isComplete(WorkoutSession session) {
    final workingSets = session.exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.setType == WorkoutSetType.working)
        .toList(growable: false);
    return workingSets.isNotEmpty &&
        workingSets.every((set) => set.completed);
  }

  static WorkoutSession? latestCompletedToday(
    Iterable<WorkoutSession> sessions,
    DateTime now,
  ) {
    // A session that began yesterday and ended after midnight belongs to
    // today's completed activity, the same rule as Progreso's calendar.
    // Never label a future-dated imported row as already finished.
    final localNow = now.toLocal();
    WorkoutSession? latest;
    for (final session in sessions) {
      final finished = session.finishedAt.toLocal();
      if (finished.year != localNow.year ||
          finished.month != localNow.month ||
          finished.day != localNow.day ||
          finished.isAfter(localNow) ||
          !isComplete(session)) {
        continue;
      }
      if (latest == null ||
          session.finishedAt.isAfter(latest.finishedAt)) {
        latest = session;
      }
    }
    return latest;
  }
}
