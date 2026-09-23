import 'package:core/domain/models/workout_analysis.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';

class ExerciseSessionComparison {
  const ExerciseSessionComparison._();

  static List<ExercisePerformanceComparison> build({
    required WorkoutSession currentSession,
    required Iterable<WorkoutSession> history,
  }) {
    final currentExercises = currentSession.exercises
        .where(_hasCompletedWorkingSet)
        .toList(growable: false);
    if (currentExercises.isEmpty) return const [];

    final previousByExercise = ExercisePerformanceMemory.latestForExercises(
      history,
      currentExercises.map((exercise) => exercise.exerciseId),
      excludeSessionId: currentSession.id,
    );

    final result = <ExercisePerformanceComparison>[];
    for (final current in currentExercises) {
      final previousEntry = previousByExercise[current.exerciseId];
      if (previousEntry == null) continue;

      final previous = previousEntry.exercise;
      final currentSets = _completedWorkingSets(current);
      final previousSets = _completedWorkingSets(previous);
      if (previousSets.isEmpty) continue;

      result.add(
        ExercisePerformanceComparison(
          exerciseId: current.exerciseId,
          exerciseName: current.exerciseNameSnapshot,
          previousPerformedAt: previousEntry.performedAt,
          previousRoutineName: previousEntry.routineName,
          currentVolume: _volume(currentSets),
          previousVolume: _volume(previousSets),
          currentWorkingSets: currentSets.length,
          previousWorkingSets: previousSets.length,
          currentBestWeight: _bestWeight(currentSets),
          previousBestWeight: _bestWeight(previousSets),
        ),
      );
    }

    return List<ExercisePerformanceComparison>.unmodifiable(result);
  }

  static bool _hasCompletedWorkingSet(WorkoutExercise exercise) =>
      exercise.sets.any(
        (set) => set.setType == WorkoutSetType.working && set.completed,
      );

  static List<WorkoutSet> _completedWorkingSets(WorkoutExercise exercise) =>
      exercise.sets
          .where(
            (set) => set.setType == WorkoutSetType.working && set.completed,
          )
          .toList(growable: false);

  static double _volume(Iterable<WorkoutSet> sets) => sets.fold<double>(
        0,
        (total, set) => total + set.performedVolume,
      );

  static double _bestWeight(Iterable<WorkoutSet> sets) {
    var best = 0.0;
    for (final set in sets) {
      final weight = set.performanceWeight;
      if (weight > best) best = weight;
    }
    return best;
  }
}
