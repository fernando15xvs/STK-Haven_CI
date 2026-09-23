import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';

class ProgramMuscleVolume {
  final String muscleGroup;
  final double plannedVolume;
  final double performedVolume;
  final int plannedWorkingSets;
  final int completedWorkingSets;

  const ProgramMuscleVolume({
    required this.muscleGroup,
    required this.plannedVolume,
    required this.performedVolume,
    required this.plannedWorkingSets,
    required this.completedWorkingSets,
  });

  double? get completionRatio =>
      plannedVolume > 0 ? performedVolume / plannedVolume : null;
}

/// Estimates planned weekly volume from each exercise's latest global load and
/// the current RoutineExercise rep target. If no prior load exists, planned
/// volume remains zero but planned set counts are still available.
class ProgramVolumePlanner {
  const ProgramVolumePlanner._();

  static List<ProgramMuscleVolume> calculateWeek({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required Iterable<WorkoutSession> history,
    required Map<String, String> muscleGroupByExerciseId,
    required DateTime weekStart,
  }) {
    final end = weekStart.add(const Duration(days: 7));
    final routineMap = <String, Routine>{
      for (final routine in routines) routine.id: routine,
    };

    final muscleGroups = <String>{};
    final plannedVolume = <String, double>{};
    final performedVolume = <String, double>{};
    final plannedSets = <String, int>{};
    final completedSets = <String, int>{};

    final memory = ExercisePerformanceMemory.latestForExercises(
      history.where((session) => session.startedAt.isBefore(weekStart)),
      program.routineIds
          .map((id) => routineMap[id])
          .whereType<Routine>()
          .expand((routine) => routine.exercises)
          .map((exercise) => exercise.exerciseId),
    );

    for (final routineId in program.routineIds) {
      final routine = routineMap[routineId];
      if (routine == null) continue;
      for (final target in routine.exercises) {
        final group = muscleGroupByExerciseId[target.exerciseId]?.trim();
        if (group == null || group.isEmpty) continue;
        muscleGroups.add(group);
        plannedSets[group] = (plannedSets[group] ?? 0) + target.targetSets;

        final latest = memory[target.exerciseId]?.latestRepresentativeSet;
        if (latest != null && latest.performanceWeight > 0) {
          final reps = target.targetRepsMin > 0 ? target.targetRepsMin : 1;
          plannedVolume[group] = (plannedVolume[group] ?? 0) +
              latest.performanceWeight * reps * target.targetSets;
        }
      }
    }

    for (final session in history) {
      if (session.startedAt.isBefore(weekStart) || !session.startedAt.isBefore(end)) {
        continue;
      }
      if (session.routineId == null ||
          !program.routineIds.contains(session.routineId)) {
        continue;
      }
      for (final exercise in session.exercises) {
        final group = exercise.muscleGroupSnapshot.trim().isNotEmpty
            ? exercise.muscleGroupSnapshot.trim()
            : muscleGroupByExerciseId[exercise.exerciseId]?.trim();
        if (group == null || group.isEmpty) continue;
        muscleGroups.add(group);
        for (final set in exercise.sets) {
          if (set.setType != WorkoutSetType.working || !set.completed) continue;
          performedVolume[group] =
              (performedVolume[group] ?? 0) + set.performedVolume;
          completedSets[group] = (completedSets[group] ?? 0) + 1;
        }
      }
    }

    final result = muscleGroups
        .map(
          (group) => ProgramMuscleVolume(
            muscleGroup: group,
            plannedVolume: plannedVolume[group] ?? 0,
            performedVolume: performedVolume[group] ?? 0,
            plannedWorkingSets: plannedSets[group] ?? 0,
            completedWorkingSets: completedSets[group] ?? 0,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.muscleGroup.compareTo(b.muscleGroup));
    return result;
  }
}
