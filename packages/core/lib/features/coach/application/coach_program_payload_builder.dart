import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';

class CoachProgramPayloadBuilder {
  const CoachProgramPayloadBuilder._();

  static Map<String, dynamic> build({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required Iterable<Exercise> exercises,
    required DateTime startsOn,
  }) {
    final routineById = <String, Routine>{
      for (final routine in routines) routine.id: routine,
    };
    final exerciseById = <String, Exercise>{
      for (final exercise in exercises) exercise.id: exercise,
    };

    if (program.routineIds.isEmpty) {
      throw ArgumentError('El programa no contiene rutinas.');
    }

    final routinePayloads = <Map<String, dynamic>>[];
    for (final routineId in program.routineIds) {
      final routine = routineById[routineId];
      if (routine == null) {
        throw StateError('Falta la rutina $routineId.');
      }
      if (routine.exercises.isEmpty) {
        throw StateError('La rutina ${routine.name} no tiene ejercicios.');
      }

      final exercisePayloads = <Map<String, dynamic>>[];
      final ordered = List<RoutineExercise>.from(routine.exercises)
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final routineExercise in ordered) {
        final exercise = exerciseById[routineExercise.exerciseId];
        if (exercise == null) {
          throw StateError(
            'Falta el ejercicio ${routineExercise.exerciseId}.',
          );
        }

        exercisePayloads.add(<String, dynamic>{
          'name': exercise.name.trim(),
          'muscle_group': exercise.muscleGroup.trim(),
          'equipment': exercise.equipment.trim(),
          'target_sets': routineExercise.targetSets,
          'target_reps_min': routineExercise.targetRepsMin,
          'target_reps_max': routineExercise.targetRepsMax,
          'rest_seconds': routineExercise.restSeconds,
          'warmup_sets': routineExercise.warmupSets,
          'approach_sets': routineExercise.approachSets,
          'unilateral': routineExercise.unilateral,
          'unilateral_target': routineExercise.unilateralTarget.name,
          'superset_key': routineExercise.supersetGroupId,
        });
      }

      routinePayloads.add(<String, dynamic>{
        'name': routine.name.trim(),
        'notes': routine.notes,
        'exercises': exercisePayloads,
      });
    }

    return <String, dynamic>{
      'name': program.name.trim(),
      'notes': program.notes,
      'duration_weeks': program.durationWeeks,
      'training_weekdays': program.trainingWeekdays.toList()..sort(),
      'starts_on': _date(startsOn),
      'routines': routinePayloads,
    };
  }

  static String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
