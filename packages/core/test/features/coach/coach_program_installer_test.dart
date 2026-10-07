import 'dart:io';

import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/coach/application/coach_program_installer.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
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

  setUpAll(registerHiveAdapters);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'stk_coach_program_install_',
    );
    Hive.init(tempDir.path);

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


  test(
    'accepted revision install is idempotent and revision-aware',
    () async {
      final installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );

      final revision2 = _acceptedRevision(
        revisionId: 'revision-2',
        revisionNumber: 2,
        name: 'Coach plan R2',
        restSeconds: 150,
      );

      final first = await installer.installAcceptedRevision(
        revision2,
        activate: false,
      );
      expect(programRepository.getAll(), hasLength(1));
      expect(first.isActive, isFalse);

      final repeated = await installer.installAcceptedRevision(
        revision2,
        activate: true,
      );
      expect(repeated.id, first.id);
      expect(repeated.isActive, isTrue);
      expect(programRepository.getAll(), hasLength(1));
      expect(
        installer
            .getInstalledRevision('assignment-1', 'revision-2')
            ?.id,
        first.id,
      );

      final revision3 = _acceptedRevision(
        revisionId: 'revision-3',
        revisionNumber: 3,
        name: 'Coach plan R3',
        restSeconds: 180,
      );
      final newer = await installer.installAcceptedRevision(
        revision3,
        activate: false,
      );

      expect(newer.id, first.id);
      expect(newer.name, 'Coach plan R3');
      expect(programRepository.getAll(), hasLength(1));
      // The old routine remains locally available for historical references,
      // while the upgraded program points at a fresh immutable prescription.
      expect(routineRepository.getAllRoutines(), hasLength(2));
      expect(
        installer.getInstalledRevision('assignment-1', 'revision-2'),
        isNull,
      );
      expect(
        installer
            .getInstalledRevision('assignment-1', 'revision-3')
            ?.id,
        first.id,
      );

      final metadata = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.revisionImportsMetadataKey,
            ) as Map,
      );
      final assignmentImports =
          Map<String, dynamic>.from(metadata['assignment-1'] as Map);
      expect(assignmentImports, hasLength(1));
      expect(assignmentImports['revision-3'], first.id);

      final managed = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.revisionInstallStateMetadataKey,
            ) as Map,
      );
      final managedAssignment =
          Map<String, dynamic>.from(managed['assignment-1'] as Map);
      expect(managedAssignment['program_id'], first.id);
      expect(managedAssignment['revision_id'], 'revision-3');
      expect(managedAssignment['revision_number'], 3);
      expect(managedAssignment['baseline'], isA<Map>());
    },
  );

  test(
    'customized imported program requires explicit overwrite confirmation',
    () async {
      final installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );
      final revision2 = _acceptedRevision(
        revisionId: 'revision-2',
        revisionNumber: 2,
        name: 'Coach plan R2',
        restSeconds: 150,
      );
      final first = await installer.installAcceptedRevision(
        revision2,
        activate: false,
      );

      await programRepository.save(
        first.copyWith(name: 'Mi versión personalizada'),
      );

      final revision3 = _acceptedRevision(
        revisionId: 'revision-3',
        revisionNumber: 3,
        name: 'Coach plan R3',
        restSeconds: 180,
      );
      final inspection =
          await installer.inspectAcceptedRevision(revision3);

      expect(inspection.upgradesExistingProgram, isTrue);
      expect(inspection.requiresOverwriteConfirmation, isTrue);
      expect(
        inspection.localChanges,
        contains('Nombre, notas o duración del programa'),
      );

      await expectLater(
        installer.installAcceptedRevision(
          revision3,
          activate: false,
          expectedLocalStateToken: inspection.localStateToken,
        ),
        throwsA(isA<CoachProgramLocalChangesException>()),
      );
      expect(
        programRepository.getById(first.id)?.name,
        'Mi versión personalizada',
      );

      final upgraded = await installer.installAcceptedRevision(
        revision3,
        activate: false,
        allowOverwriteCustomized: true,
        expectedLocalStateToken: inspection.localStateToken,
      );
      expect(upgraded.id, first.id);
      expect(upgraded.name, 'Coach plan R3');
    },
  );

  test(
    'revision upgrade aborts when local state changes after inspection',
    () async {
      final installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );
      final first = await installer.installAcceptedRevision(
        _acceptedRevision(
          revisionId: 'revision-2',
          revisionNumber: 2,
          name: 'Coach plan R2',
          restSeconds: 150,
        ),
        activate: false,
      );
      final revision3 = _acceptedRevision(
        revisionId: 'revision-3',
        revisionNumber: 3,
        name: 'Coach plan R3',
        restSeconds: 180,
      );
      final inspection =
          await installer.inspectAcceptedRevision(revision3);
      expect(inspection.requiresOverwriteConfirmation, isFalse);

      await programRepository.save(
        first.copyWith(notes: 'Cambio posterior a la revisión'),
      );

      await expectLater(
        installer.installAcceptedRevision(
          revision3,
          activate: false,
          allowOverwriteCustomized: true,
          expectedLocalStateToken: inspection.localStateToken,
        ),
        throwsA(isA<CoachProgramInstallStateChangedException>()),
      );
      expect(
        programRepository.getById(first.id)?.notes,
        'Cambio posterior a la revisión',
      );
      expect(
        installer.getInstalledRevision('assignment-1', 'revision-3'),
        isNull,
      );
    },
  );
}

AcceptedProgramRevisionSnapshot _acceptedRevision({
  required String revisionId,
  required int revisionNumber,
  required String name,
  required int restSeconds,
}) {
  return AcceptedProgramRevisionSnapshot(
    assignmentId: 'assignment-1',
    relationshipId: 'relationship-1',
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    sourceKind: 'coach_revision',
    name: name,
    notes: 'Revision notes',
    durationWeeks: 8,
    trainingWeekdays: const {1, 3, 5},
    startsOn: DateTime(2026, 10, 12),
    acceptedAt: DateTime(2026, 10, 6),
    routines: [
      AssignedRoutineSnapshot(
        id: 'remote-routine-$revisionId',
        position: 0,
        name: 'Upper',
        notes: 'Routine notes',
        exercises: [
          AssignedExerciseSnapshot(
            id: 'remote-exercise-$revisionId',
            position: 0,
            name: 'Remo unilateral',
            muscleGroup: 'Espalda',
            equipment: 'Mancuerna',
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: restSeconds,
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
}
