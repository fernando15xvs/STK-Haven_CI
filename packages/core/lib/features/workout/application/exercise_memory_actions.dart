import 'package:core/domain/models/workout_session.dart';

/// Pure helpers for applying Exercise Memory values to an active workout.
///
/// They never mark work as completed and they preserve the current routine's
/// set type/rest configuration. Historical side-specific values are normalized
/// to the conservative performance fields when used as a shared prefill.
class ExerciseMemoryActions {
  const ExerciseMemoryActions._();

  static WorkoutExercise applyPreviousExercise({
    required WorkoutExercise current,
    required WorkoutExercise previousAligned,
  }) {
    final nextSets = <WorkoutSet>[];

    for (var index = 0; index < current.sets.length; index++) {
      final target = current.sets[index];

      // Never overwrite work that the user has already completed in the
      // current session, including a partially completed unilateral set.
      if (target.completed || target.leftCompleted || target.rightCompleted) {
        nextSets.add(target);
        continue;
      }

      if (index >= previousAligned.sets.length) {
        nextSets.add(target);
        continue;
      }

      final source = previousAligned.sets[index];
      if (!source.completed || source.setType != target.setType) {
        nextSets.add(target);
        continue;
      }

      nextSets.add(
        target.copyWith(
          weight: source.performanceWeight,
          reps: source.performanceReps,
          rir: source.performanceRir,
          clearRir: source.performanceRir == null,
          completed: false,
          leftCompleted: false,
          rightCompleted: false,
          clearLeftPerformance: true,
          clearRightPerformance: true,
        ),
      );
    }

    return current.copyWith(sets: nextSets);
  }

  /// Copies values from the nearest previous set of the same type in the
  /// current exercise. Completion/side state is intentionally reset.
  static WorkoutExercise copyPreviousSet({
    required WorkoutExercise current,
    required int setIndex,
  }) {
    if (setIndex <= 0 || setIndex >= current.sets.length) return current;

    final target = current.sets[setIndex];
    if (target.completed || target.leftCompleted || target.rightCompleted) {
      return current;
    }

    WorkoutSet? source;
    for (var index = setIndex - 1; index >= 0; index--) {
      final candidate = current.sets[index];
      if (candidate.setType == target.setType) {
        source = candidate;
        break;
      }
    }
    if (source == null) return current;

    final copied = target.copyWith(
      weight: source.weight,
      reps: source.reps,
      rir: source.rir,
      clearRir: source.rir == null,
      completed: false,
      leftCompleted: false,
      rightCompleted: false,
      clearLeftPerformance: true,
      clearRightPerformance: true,
    );

    final nextSets = List<WorkoutSet>.from(current.sets);
    nextSets[setIndex] = copied;
    return current.copyWith(sets: nextSets);
  }
}
