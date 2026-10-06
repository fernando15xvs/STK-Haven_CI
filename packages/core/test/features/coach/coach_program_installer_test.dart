import 'dart:io';

import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/coach/application/coach_program_installer.dart';
import 'package:core/features/exercises/data/exercise_repository.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<HiveExercise> exerciseBox;
  late Box<HiveRoutine> routineBox;
  late Box<dynamic> programBox;
  late Box<dynamic> metadataBox;
  late ExerciseRepository exerciseRepository;
  late RoutineRepository routineRepository;
  late TrainingProgramRepository programRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'stk_coach_program_install_',
    );
    Hive.init(tempDir.path);
    registerHiveAdapters();

    exerciseBox = await Hive.openBox<HiveExercise>('exercises');
    routineBox = await Hive.openBox<HiveRoutine>('routines');
    programBox = await Hive.openBox<dynamic>('programs');
    metadataBox = await Hive.openBox<dynamic>('metadata');

    exerciseRepository = ExerciseRepository(exerciseBox);
    routineRepository = RoutineRepository(routineBox);
    programRepository = TrainingProgramRepository(
      programBox,
      metadataBox: metadataBox,
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('installer preserves preparation and unilateral prescription', () async {
    final installer = CoachProgramInstaller(
      exerciseRepository: exerciseRepository,
      routineRepository: routineRepository,
      programRepository: programRepository,
      metadataBox: metadataBox,
    );

    final assignment = CoachProgramAssignment(
      summary: CoachProgramAssignmentSummary(
        id: 'assignment-1',
        relationshipId: 'relationship-1',
        coachUserId: 'coach-1',
        clientUserId: 'client-1',
        name: 'Coach plan',
        durationWeeks: 8,
        trainingWeekdays: const {1, 3, 5},
        startsOn: DateTime(2026, 10, 12),
        status: AssignedProgramStatus.accepted,
        version: 1,
        createdAt: DateTime(2026, 10, 6),
        acceptedAt: DateTime(2026, 10, 6),
        updatedAt: DateTime(2026, 10, 6),
      ),
      notes: '',
      routines: const [
        AssignedRoutineSnapshot(
          id: 'remote-routine',
          position: 0,
          name: 'Upper',
          notes: '',
          exercises: [
            AssignedExerciseSnapshot(
              id: 'remote-exercise',
              position: 0,
              name: 'Remo unilateral',
              muscleGroup: 'Espalda',
              equipment: 'Mancuerna',
              targetSets: 3,
              targetRepsMin: 8,
              targetRepsMax: 12,
              restSeconds: 150,
              warmupSets: 1,
              approachSets: 2,
              warmupRestSeconds: 45,
              approachRestSeconds: 75,
              unilateral: true,
              unilateralTarget: 'back',
              preparationUnilateral: false,
              unilateralSideRestSeconds: 0,
              preferredUnilateralStartSide: PreferredWorkoutSide.right,
            ),
          ],
        ),
      ],
    );

    await installer.install(assignment, activate: false);

    final installed = routineRepository.getAllRoutines().single;
    final exercise = installed.exercises.single;

    expect(exercise.restSeconds, 150);
    expect(exercise.warmupSets, 1);
    expect(exercise.approachSets, 2);
    expect(exercise.warmupRestSeconds, 45);
    expect(exercise.approachRestSeconds, 75);
    expect(exercise.unilateral, isTrue);
    expect(exercise.preparationUnilateral, isFalse);
    expect(exercise.unilateralSideRestSeconds, 0);
    expect(
      exercise.preferredUnilateralStartSide,
      PreferredWorkoutSide.right,
    );
  });
}
