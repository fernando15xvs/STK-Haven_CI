import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_muscle_frequency_planner.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('five-day Upper/Lower counts muscle frequency per session', () {
    final monday = DateTime(2026, 9, 28);
    final routines = <Routine>[
      _routine('ua', ['bench', 'row']),
      _routine('la', ['squat', 'curl-leg']),
      _routine('ub', ['ohp', 'pulldown']),
      _routine('lb', ['leg-press', 'rdl']),
    ];
    final exercises = <Exercise>[
      Exercise(
        id: 'bench',
        name: 'Press banca',
        muscleGroup: 'Pecho',
        secondaryMuscles: const ['Tríceps', 'Hombros'],
      ),
      Exercise(
        id: 'row',
        name: 'Remo',
        muscleGroup: 'Espalda',
        secondaryMuscles: const ['Bíceps'],
      ),
      Exercise(
        id: 'squat',
        name: 'Sentadilla',
        muscleGroup: 'Cuádriceps',
        secondaryMuscles: const ['Glúteos'],
      ),
      Exercise(
        id: 'curl-leg',
        name: 'Curl femoral',
        muscleGroup: 'Isquiotibiales',
      ),
      Exercise(
        id: 'ohp',
        name: 'Press militar',
        muscleGroup: 'Hombros',
        secondaryMuscles: const ['Tríceps'],
      ),
      Exercise(
        id: 'pulldown',
        name: 'Jalón',
        muscleGroup: 'Espalda',
        secondaryMuscles: const ['Bíceps'],
      ),
      Exercise(
        id: 'leg-press',
        name: 'Prensa',
        muscleGroup: 'Cuádriceps',
        secondaryMuscles: const ['Glúteos'],
      ),
      Exercise(
        id: 'rdl',
        name: 'Peso muerto rumano',
        muscleGroup: 'Isquiotibiales',
      ),
    ];
    final program = TrainingProgram(
      id: 'p',
      name: 'Upper Lower',
      routineIds: const ['ua', 'la', 'ub', 'lb'],
      createdAt: monday,
      startedAt: monday,
      scheduleMode: ProgramScheduleMode.continuous,
      targetSessionsPerWeek: 5,
      trainingWeekdays:
          ProgramScheduleProjector.recommendedTrainingWeekdays(5),
    );

    final frequency = ProgramMuscleFrequencyPlanner.calculateWeek(
      program: program,
      routines: routines,
      exercises: exercises,
      weekStart: monday,
    );
    final byGroup = {
      for (final item in frequency) item.muscleGroup: item,
    };

    // Week = UA, LA, UB, LB, UA.
    expect(byGroup['Pecho']?.totalSessions, 2);
    expect(byGroup['Pecho']?.directSessions, 2);
    expect(byGroup['Espalda']?.totalSessions, 3);
    expect(byGroup['Espalda']?.directSessions, 3);
    expect(byGroup['Hombros']?.totalSessions, 3);
    expect(byGroup['Hombros']?.directSessions, 1);
    expect(byGroup['Tríceps']?.totalSessions, 3);
    expect(byGroup['Tríceps']?.directSessions, 0);
    expect(byGroup['Cuádriceps']?.totalSessions, 2);
    expect(byGroup['Bíceps']?.totalSessions, 3);
  });
}

Routine _routine(String id, List<String> exerciseIds) {
  return Routine(
    id: id,
    name: id,
    scheduledDays: const [],
    createdAt: DateTime(2026, 9, 1),
    exercises: [
      for (var index = 0; index < exerciseIds.length; index++)
        RoutineExercise(
          exerciseId: exerciseIds[index],
          order: index,
          targetSets: 3,
          targetRepsMin: 8,
          targetRepsMax: 12,
          restSeconds: 90,
        ),
    ],
  );
}
