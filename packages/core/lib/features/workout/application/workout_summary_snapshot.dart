import 'package:core/domain/models/workout_session.dart';

class WorkoutExerciseSummary {
  final String exerciseId;
  final String exerciseName;
  final int plannedWorkingSets;
  final int completedWorkingSets;

  const WorkoutExerciseSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.plannedWorkingSets,
    required this.completedWorkingSets,
  });

  bool get isComplete =>
      plannedWorkingSets > 0 && completedWorkingSets == plannedWorkingSets;

  double get completionRatio {
    if (plannedWorkingSets <= 0) return 0;
    return (completedWorkingSets / plannedWorkingSets)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get completionPercent => (completionRatio * 100).round();
}

/// Presentation-ready, neutral snapshot of what was recorded in a session.
class WorkoutSummarySnapshot {
  final List<WorkoutExerciseSummary> exercises;
  final int plannedWorkingSets;
  final int completedWorkingSets;
  final int completedExercises;
  final double? averageRir;
  final int rirLoggedSets;

  const WorkoutSummarySnapshot({
    required this.exercises,
    required this.plannedWorkingSets,
    required this.completedWorkingSets,
    required this.completedExercises,
    required this.averageRir,
    required this.rirLoggedSets,
  });

  factory WorkoutSummarySnapshot.fromSession(WorkoutSession session) {
    final exercises = <WorkoutExerciseSummary>[];
    var plannedSets = 0;
    var completedSets = 0;
    var completedExerciseCount = 0;
    var rirTotal = 0;
    var rirCount = 0;

    for (final exercise in session.exercises) {
      final workingSets = exercise.sets
          .where((set) => set.setType == WorkoutSetType.working)
          .toList(growable: false);
      if (workingSets.isEmpty) continue;

      final completed = workingSets.where((set) => set.completed).length;
      final exerciseSummary = WorkoutExerciseSummary(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseNameSnapshot,
        plannedWorkingSets: workingSets.length,
        completedWorkingSets: completed,
      );
      exercises.add(exerciseSummary);
      plannedSets += workingSets.length;
      completedSets += completed;
      if (exerciseSummary.isComplete) completedExerciseCount++;

      for (final set in workingSets) {
        final effectiveRir = set.performanceRir;
        if (set.completed && effectiveRir != null) {
          rirTotal += effectiveRir;
          rirCount++;
        }
      }
    }

    return WorkoutSummarySnapshot(
      exercises: List<WorkoutExerciseSummary>.unmodifiable(exercises),
      plannedWorkingSets: plannedSets,
      completedWorkingSets: completedSets,
      completedExercises: completedExerciseCount,
      averageRir: rirCount == 0 ? null : rirTotal / rirCount,
      rirLoggedSets: rirCount,
    );
  }

  int get totalExercises => exercises.length;

  double get completionRatio {
    if (plannedWorkingSets <= 0) return 0;
    return (completedWorkingSets / plannedWorkingSets)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get completionPercent => (completionRatio * 100).round();

  bool get isComplete =>
      plannedWorkingSets > 0 && completedWorkingSets == plannedWorkingSets;
}
