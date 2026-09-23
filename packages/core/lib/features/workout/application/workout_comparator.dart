import '../../../domain/models/workout_session.dart';
import '../../../domain/models/workout_analysis.dart';

class WorkoutComparator {
  static SessionComparison? compare({
    required WorkoutSession currentSession,
    required WorkoutSession? previousSession,
  }) {
    if (previousSession == null) return null;

    final currentVolume = calculateVolume(currentSession);
    final previousVolume = calculateVolume(previousSession);

    final currentSets = calculateSets(currentSession);
    final previousSets = calculateSets(previousSession);

    double volumeDiffPercent = 0.0;
    if (previousVolume > 0) {
      volumeDiffPercent =
          ((currentVolume - previousVolume) / previousVolume) * 100;
    }

    return SessionComparison(
      previousVolume: previousVolume,
      volumeDifferencePercent: volumeDiffPercent,
      setsDifference: currentSets - previousSets,
      durationDifferenceSeconds:
          currentSession.durationSeconds - previousSession.durationSeconds,
    );
  }

  static double calculateVolume(WorkoutSession session) {
    double vol = 0;
    for (final ex in session.exercises) {
      for (final set in ex.sets) {
        if (set.completed && !set.warmup) {
          vol += set.performedVolume;
        }
      }
    }
    return vol;
  }

  static int calculateSets(WorkoutSession session) {
    int sets = 0;
    for (final ex in session.exercises) {
      sets += ex.sets.where((s) => s.completed && !s.warmup).length;
    }
    return sets;
  }
}
