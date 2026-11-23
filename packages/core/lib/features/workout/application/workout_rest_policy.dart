import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'superset_coordinator.dart';

/// Resolves rest from the live order, so reordered/added sets are respected.
class WorkoutRestPolicy {
  static SupersetRestDecision decide({
    required RestTimingMode mode,
    required List<WorkoutExercise> exercises,
    required int exerciseIndex,
    required int setIndex,
  }) {
    final exercise = exercises[exerciseIndex];
    final completed = exercise.sets[setIndex];
    // A unilateral set is complete only after both sides. Never start a
    // redundant post-set countdown when it was the final pending set in the
    // entire workout, regardless of completed/next-set rest preference.
    if (exercise.usesUnilateralTracking(completed) &&
        completed.completed &&
        !exercises.any((entry) => entry.sets.any((set) => !set.completed))) {
      return const SupersetRestDecision(
        shouldStartRest: false,
        restSeconds: 0,
      );
    }
    // Supersets are an explicit round-based training mode, independent of this
    // preference. Inter-side rest is handled by UnilateralSetCoordinator.
    if (mode == RestTimingMode.completedSet ||
        (exercise.supersetGroupId != null &&
            completed.setType == WorkoutSetType.working)) {
      return SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
      );
    }
    // Start after the completed slot, wrap once to cover skipped earlier sets.
    final slots = [for (final ex in exercises) ...ex.sets];
    final cursor =
        exercises
            .take(exerciseIndex)
            .fold<int>(0, (count, ex) => count + ex.sets.length) +
        setIndex;
    for (var offset = 1; offset < slots.length; offset++) {
      final next = slots[(cursor + offset) % slots.length];
      if (!next.completed) {
        return SupersetRestDecision(
          shouldStartRest: next.restSeconds > 0,
          restSeconds: next.restSeconds,
        );
      }
    }
    return const SupersetRestDecision(shouldStartRest: false, restSeconds: 0);
  }
}
