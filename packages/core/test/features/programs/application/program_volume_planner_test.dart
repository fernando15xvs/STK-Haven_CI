import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_volume_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly planned sets follow repeated sessions in a 5-day rotation', () {
    final monday = DateTime(2026, 9, 7);
    final routines = <Routine>[
      _routine('ua', 'upper-a', 3),
      _routine('la', 'lower-a', 4),
      _routine('ub', 'upper-b', 5),
      _routine('lb', 'lower-b', 6),
    ];
    final program = TrainingProgram(
      id: 'p',
      name: 'Upper / Lower continuo',
      routineIds: const ['ua', 'la', 'ub', 'lb'],
      createdAt: monday,
      startedAt: monday,
      trainingWeekdays:
          ProgramScheduleProjector.recommendedTrainingWeekdays(5),
    );

    final volumes = ProgramVolumePlanner.calculateWeek(
      program: program,
      routines: routines,
      history: const [],
      muscleGroupByExerciseId: const {
        'upper-a': 'Torso',
        'upper-b': 'Torso',
        'lower-a': 'Pierna',
        'lower-b': 'Pierna',
      },
      weekStart: monday,
    );

    final byMuscle = {
      for (final volume in volumes) volume.muscleGroup: volume,
    };

    expect(byMuscle['Torso']?.plannedWorkingSets, 11);
    expect(byMuscle['Pierna']?.plannedWorkingSets, 10);
  });
}

Routine _routine(String id, String exerciseId, int targetSets) {
  return Routine(
    id: id,
    name: id,
    scheduledDays: const [],
    createdAt: DateTime(2026, 9, 1),
    exercises: [
      RoutineExercise(
        exerciseId: exerciseId,
        order: 0,
        targetSets: targetSets,
        targetRepsMin: 8,
        targetRepsMax: 12,
        restSeconds: 90,
      ),
    ],
  );
}
