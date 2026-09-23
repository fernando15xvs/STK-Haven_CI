import 'package:core/domain/models/workout_session.dart';

class MuscleWorkloadCalculator {
  /// Calculates the effective sets per muscle group from a list of sessions.
  /// Only counts completed and non-warmup sets.
  /// Returns a map where the key is the muscle group name and the value is the total effective sets.
  static Map<String, double> calculate(List<WorkoutSession> sessions) {
    final Map<String, double> workload = {};

    for (final session in sessions) {
      for (final exercise in session.exercises) {
        final muscle = exercise.muscleGroupSnapshot;
        if (muscle.isEmpty) continue;

        double effectiveSets = 0;
        for (final set in exercise.sets) {
          if (set.completed && !set.warmup) {
            // For now, primary muscle = 1.0 set.
            // In the future, this can be sophisticated to include secondary muscles.
            effectiveSets += 1.0;
          }
        }

        if (effectiveSets > 0) {
          workload[muscle] = (workload[muscle] ?? 0) + effectiveSets;
        }
      }
    }

    return workload;
  }
}
