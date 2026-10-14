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
    WorkoutSession? latest;
    for (final session in sessions) {
      final started = session.startedAt.toLocal();
      if (started.year != now.year ||
          started.month != now.month ||
          started.day != now.day ||
          !isComplete(session)) {
        continue;
      }
      if (latest == null ||
          session.startedAt.isAfter(latest.startedAt)) {
        latest = session;
      }
    }
    return latest;
  }
}
