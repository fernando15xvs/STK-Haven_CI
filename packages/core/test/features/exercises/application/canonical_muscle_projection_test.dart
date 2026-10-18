import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/canonical_muscle_projection.dart';
import 'package:core/features/programs/application/program_muscle_frequency_planner.dart';
import 'package:core/features/programs/application/program_volume_planner.dart';
import 'package:core/features/progress/application/muscle_balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy aliases consolidate only at verified reporting group level', () {
    for (final alias in ['Hombro', 'Hombros', 'hombros',
        'Hombro anterior', 'Deltoides lateral']) {
      expect(CanonicalMuscleProjector.resolve(alias)!.key, 'mg_shoulders');
    }
    expect(CanonicalMuscleProjector.resolve('Hombro')!.isSpecific, false);
    expect(CanonicalMuscleProjector.resolve('Hombro posterior')!.anatomyId,
        'reg_deltoid_posterior');
    expect(CanonicalMuscleProjector.resolve('Hombro')!.anatomyId,
        'mg_shoulders');
    expect(CanonicalMuscleProjector.resolve('Dorsal')!.key, 'mg_back');
    expect(CanonicalMuscleProjector.resolve('Espalda')!.key, 'mg_back');
    expect(CanonicalMuscleProjector.resolve('Pecho superior')!.key, 'mg_chest');
    expect(CanonicalMuscleProjector.resolve('Pecho medio')!.key, 'mg_chest');
    expect(CanonicalMuscleProjector.resolve('Pecho inferior')!.key, 'mg_chest');
    expect(CanonicalMuscleProjector.resolve('Isquios')!.key, 'mg_hamstrings');
    expect(CanonicalMuscleProjector.resolve('Isquiotibiales')!.key,
        'mg_hamstrings');
    expect(CanonicalMuscleProjector.resolve('Oblicuo externo')!.key,
        'mg_obliques');
    expect(CanonicalMuscleProjector.resolve('Serrato anterior')!.key,
        'mg_shoulder_girdle');
    expect(CanonicalMuscleProjector.resolve('Serrato anterior')!.anatomyId,
        'm_serratus_anterior');
    expect(CanonicalMuscleProjector.resolve('') , isNull);
  });

  test('compound and unknown labels remain reviewable without assumptions', () {
    for (final raw in ['Tríceps y hombro', 'Glúteos e isquios', 'inventado']) {
      final p = CanonicalMuscleProjector.resolve(raw)!;
      expect(p.requiresReview, true);
      expect(p.reportGroupId, isNull);
      expect(p.anatomyId, isNull);
      expect(p.originalLabel, raw);
      expect(p.key.startsWith('legacy:'), true);
    }
    expect(CanonicalMuscleProjector.resolve('Hombros')!.requiresReview, true);
    expect(CanonicalMuscleProjector.resolve('Hombros')!.reportGroupId,
        'mg_shoulders');
  });

  final monday = DateTime(2026, 10, 12);
  final routine = Routine(
    id: 'r1',
    name: 'Upper A',
    scheduledDays: const [DateTime.monday],
    createdAt: DateTime(2026, 10, 1),
    exercises: const [
      RoutineExercise(
        exerciseId: 'old', order: 0, targetSets: 3,
        targetRepsMin: 8, targetRepsMax: 10, restSeconds: 90,
      ),
      RoutineExercise(
        exerciseId: 'new', order: 1, targetSets: 2,
        targetRepsMin: 8, targetRepsMax: 10, restSeconds: 90,
      ),
    ],
  );
  final program = TrainingProgram(
    id: 'p1', name: 'Upper',
    routineIds: const ['r1'],
    createdAt: monday, startedAt: monday,
    scheduleMode: ProgramScheduleMode.continuous,
    targetSessionsPerWeek: 1,
    trainingWeekdays: const {DateTime.monday},
  );
  final catalog = [
    Exercise(id: 'old', name: 'Press antiguo',
        muscleGroup: 'Hombros',
        secondaryMuscles: const ['Tríceps', 'TRICEPS', 'Hombro anterior']),
    Exercise(id: 'new', name: 'Elevaciones',
        muscleGroup: 'Hombro lateral'),
  ];
  final history = [
    WorkoutSession(
      id: 'session-1', routineId: 'r1',
      routineNameSnapshot: 'Upper A',
      startedAt: DateTime(2026, 10, 12, 10),
      finishedAt: DateTime(2026, 10, 12, 11),
      durationSeconds: 3600,
      exercises: const [
        WorkoutExercise(
          exerciseId: 'old', exerciseNameSnapshot: 'Press histórico',
          muscleGroupSnapshot: 'Hombro',
          sets: [
            WorkoutSet(weight: 20, reps: 10, completed: true),
            WorkoutSet(weight: 10, reps: 10, completed: true,
                setType: WorkoutSetType.warmup),
          ],
        ),
        WorkoutExercise(
          exerciseId: 'new', exerciseNameSnapshot: 'Elevaciones',
          muscleGroupSnapshot: 'Hombro lateral',
          unilateral: true,
          sets: [
            WorkoutSet(weight: 8, reps: 10, completed: true,
                leftCompleted: true, rightCompleted: true,
                leftWeight: 8, rightWeight: 8,
                leftReps: 10, rightReps: 10),
          ],
        ),
      ],
    ),
  ];

  test('program frequency counts one category per scheduled session', () {
    final rows = ProgramMuscleFrequencyPlanner.calculateWeek(
      program: program, routines: [routine], exercises: catalog,
      weekStart: monday,
    );
    final shoulders = rows.where((e) => e.canonicalGroupId == 'mg_shoulders')
        .single;
    expect(shoulders.muscleGroup, 'Hombros');
    expect(shoulders.totalSessions, 1);
    expect(shoulders.directSessions, 1);
    expect(rows.where((e) => e.canonicalGroupId == 'mg_shoulders').length, 1);
    expect(rows.where((e) => e.canonicalGroupId == 'mg_triceps').single
        .secondaryOnlySessions, 1);
  });

  test('program volume pairs planned with immutable historical snapshot', () {
    final before = history.single.exercises.first.muscleGroupSnapshot;
    final rows = ProgramVolumePlanner.calculateWeek(
      program: program, routines: [routine], history: history,
      muscleGroupByExerciseId: {'old': 'Hombros', 'new': 'Hombro lateral'},
      weekStart: monday,
    );
    final shoulders = rows.where((e) => e.canonicalGroupId == 'mg_shoulders')
        .single;
    expect(shoulders.plannedWorkingSets, 5);
    expect(shoulders.completedWorkingSets, 2);
    expect(shoulders.performedVolume, 280);
    expect(history.single.exercises.first.muscleGroupSnapshot, before);
    expect(rows.where((e) => e.canonicalGroupId == 'mg_shoulders').length, 1);
  });

  test('muscle balance avoids parent/portion and secondary double count', () {
    final report = MuscleBalanceCalculator.calculate(
      history: history, exercises: catalog, routines: [routine],
      from: monday, now: DateTime(2026, 10, 18, 12),
    );
    final shoulders = report.groups
        .where((e) => e.canonicalGroupId == 'mg_shoulders').single;
    expect(shoulders.directSets, 2);
    expect(shoulders.trainingDays, 1);
    expect(shoulders.estimatedSecondarySets, 0);
    expect(shoulders.plannedSetsInPerformedSessions, 5);
    expect(shoulders.completedSetsInPlannedExercises, 2);
    expect(report.totalDirectSets, 2);
    expect(report.groups.where((e) => e.canonicalGroupId == 'mg_triceps')
        .single.estimatedSecondarySets, 0.5);
    expect(history.single.exercises.first.muscleGroupSnapshot, 'Hombro');
    expect(history.single.exercises.first.sets.length, 2);
  });
}
