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
    'local customizations require confirmation and remain preserved',
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
      final localRoutine = routineRepository.getAllRoutines().single;
      await routineRepository.updateRoutine(
        localRoutine.copyWith(
          exercises: [
            localRoutine.exercises.single.copyWith(restSeconds: 240),
          ],
        ),
        preserveExistingNotes: false,
      );

      final revision3 = _acceptedRevision(
        revisionId: 'revision-3',
        revisionNumber: 3,
        name: 'Coach plan R3',
        restSeconds: 180,
      );
      final assessment =
          await installer.assessAcceptedRevision(revision3);

      expect(assessment.requiresLocalChangeConfirmation, isTrue);
      expect(
        assessment.localChanges,
        contains('Cambió el nombre o las notas del programa.'),
      );
      expect(
        assessment.localChanges,
        contains(
          'Cambió la prescripción o ejercicios de la rutina «Upper».',
        ),
      );

      await expectLater(
        installer.installAcceptedRevision(
          revision3,
          activate: false,
        ),
        throwsA(isA<CoachProgramLocalChangesException>()),
      );
      expect(programRepository.getAll(), hasLength(1));

      final newer = await installer.installAcceptedRevision(
        revision3,
        activate: false,
        confirmLocalChanges: true,
      );

      expect(newer.id, isNot(first.id));
      expect(programRepository.getAll(), hasLength(2));
      expect(
        programRepository.getById(first.id)?.name,
        'Mi versión personalizada',
      );
      final preservedRoutine = routineRepository
          .getAllRoutines()
          .firstWhere((routine) => routine.id == localRoutine.id);
      expect(preservedRoutine.exercises.single.restSeconds, 240);

      final managed = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.managedRevisionMetadataKey,
            ) as Map,
      );
      final state =
          Map<String, dynamic>.from(managed['assignment-1'] as Map);
      expect(state['revision_id'], 'revision-3');
      expect(state['revision_number'], 3);
      expect(state['program_id'], newer.id);
      expect(state['baseline'], isA<Map>());
    },
  );

  test(
    'accepted revision can retry after a transient local storage failure',
    () async {
      final revision = _acceptedRevision(
        revisionId: 'revision-recovery',
        revisionNumber: 5,
        name: 'Coach recovery plan',
        restSeconds: 165,
      );
      var installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );

      await routineBox.close();

      await expectLater(
        installer.installAcceptedRevision(
          revision,
          activate: false,
        ),
        throwsA(anything),
      );

      expect(exerciseRepository.getAllExercises(), isEmpty);
      expect(programRepository.getAll(), isEmpty);
      expect(
        installer.getInstalledRevision(
          revision.assignmentId,
          revision.revisionId,
        ),
        isNull,
      );

      routineBox = await Hive.openBox<HiveRoutine>('routines');
      routineRepository = RoutineRepository(routineBox);
      installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );

      final recovered = await installer.installAcceptedRevision(
        revision,
        activate: false,
      );

      expect(recovered.name, 'Coach recovery plan');
      expect(programRepository.getAll(), hasLength(1));
      expect(routineRepository.getAllRoutines(), hasLength(1));
      expect(
        installer.getInstalledRevision(
          revision.assignmentId,
          revision.revisionId,
        )?.id,
        recovered.id,
      );
    },
  );

  test(
    'accepted revision installs on a fresh device without local metadata',
    () async {
      final revision = _acceptedRevision(
        revisionId: 'revision-device',
        revisionNumber: 6,
        name: 'Device recovery plan',
        restSeconds: 170,
      );

      final device2ExerciseBox =
          await Hive.openBox<HiveExercise>('device2_exercises');
      final device2RoutineBox =
          await Hive.openBox<HiveRoutine>('device2_routines');
      final device2ProgramBox =
          await Hive.openBox<dynamic>('device2_programs');
      final device2MetadataBox =
          await Hive.openBox<dynamic>('device2_metadata');
      final device2ExerciseRepository =
          ExerciseRepository(device2ExerciseBox);
      final device2RoutineRepository =
          RoutineRepository(device2RoutineBox);
      final device2ProgramRepository = TrainingProgramRepository(
        device2ProgramBox,
        metadataBox: device2MetadataBox,
      );
      final device2Installer = CoachProgramInstaller(
        exerciseRepository: device2ExerciseRepository,
        routineRepository: device2RoutineRepository,
        programRepository: device2ProgramRepository,
        metadataBox: device2MetadataBox,
      );

      final before =
          await device2Installer.assessAcceptedRevision(revision);
      expect(before.targetAlreadyInstalled, isFalse);
      expect(before.installedProgramId, isNull);
      expect(before.localChanges, isEmpty);

      final installed = await device2Installer.installAcceptedRevision(
        revision,
        activate: true,
      );

      expect(installed.isActive, isTrue);
      expect(device2ProgramRepository.getAll(), hasLength(1));
      expect(device2RoutineRepository.getAllRoutines(), hasLength(1));
      expect(
        device2Installer.getInstalledRevision(
          revision.assignmentId,
          revision.revisionId,
        )?.id,
        installed.id,
      );
    },
  );

  test(
    'same revision id from different assignments never collides locally',
    () async {
      final installer = CoachProgramInstaller(
        exerciseRepository: exerciseRepository,
        routineRepository: routineRepository,
        programRepository: programRepository,
        metadataBox: metadataBox,
      );
      final coachA = _acceptedRevision(
        assignmentId: 'assignment-coach-a',
        relationshipId: 'relationship-coach-a',
        revisionId: 'revision-2',
        revisionNumber: 2,
        name: 'Plan coach A',
        restSeconds: 140,
      );
      final coachB = _acceptedRevision(
        assignmentId: 'assignment-coach-b',
        relationshipId: 'relationship-coach-b',
        revisionId: 'revision-2',
        revisionNumber: 2,
        name: 'Plan coach B',
        restSeconds: 200,
      );

      final installedA = await installer.installAcceptedRevision(
        coachA,
        activate: false,
      );
      final installedB = await installer.installAcceptedRevision(
        coachB,
        activate: false,
      );

      expect(installedA.id, isNot(installedB.id));
      expect(programRepository.getAll(), hasLength(2));
      expect(
        installer.getInstalledRevision(
          coachA.assignmentId,
          coachA.revisionId,
        )?.id,
        installedA.id,
      );
      expect(
        installer.getInstalledRevision(
          coachB.assignmentId,
          coachB.revisionId,
        )?.id,
        installedB.id,
      );

      final imports = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.revisionImportsMetadataKey,
            ) as Map,
      );
      expect(
        Map<String, dynamic>.from(
          imports[coachA.assignmentId] as Map,
        )[coachA.revisionId],
        installedA.id,
      );
      expect(
        Map<String, dynamic>.from(
          imports[coachB.assignmentId] as Map,
        )[coachB.revisionId],
        installedB.id,
      );
    },
  );

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

      expect(newer.id, isNot(first.id));
      expect(programRepository.getAll(), hasLength(2));
      expect(routineRepository.getAllRoutines(), hasLength(2));
      expect(
        installer
            .getInstalledRevision('assignment-1', 'revision-2')
            ?.id,
        first.id,
      );
      expect(
        installer
            .getInstalledRevision('assignment-1', 'revision-3')
            ?.id,
        newer.id,
      );

      final metadata = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.revisionImportsMetadataKey,
            ) as Map,
      );
      final assignmentImports =
          Map<String, dynamic>.from(metadata['assignment-1'] as Map);
      expect(assignmentImports['revision-2'], first.id);
      expect(assignmentImports['revision-3'], newer.id);

      final revision4 = _acceptedRevision(
        revisionId: 'revision-4',
        revisionNumber: 4,
        name: 'Coach plan R4',
        restSeconds: 210,
      );
      final newest = await installer.installAcceptedRevision(
        revision4,
        activate: false,
      );

      expect(programRepository.getAll(), hasLength(3));
      expect(
        installer.getInstalledRevision(
          'assignment-1',
          'revision-2',
        )?.id,
        first.id,
      );
      expect(
        installer.getInstalledRevision(
          'assignment-1',
          'revision-3',
        )?.id,
        newer.id,
      );
      expect(
        installer.getInstalledRevision(
          'assignment-1',
          'revision-4',
        )?.id,
        newest.id,
      );

      final managed = Map<String, dynamic>.from(
        metadataBox.get(
              CoachProgramInstaller.managedRevisionMetadataKey,
            ) as Map,
      );
      final managedAssignment =
          Map<String, dynamic>.from(managed['assignment-1'] as Map);
      expect(managedAssignment['revision_id'], 'revision-4');
      expect(managedAssignment['revision_number'], 4);
      expect(managedAssignment['program_id'], newest.id);
    },
  );
}

AcceptedProgramRevisionSnapshot _acceptedRevision({
  String assignmentId = 'assignment-1',
  String relationshipId = 'relationship-1',
  required String revisionId,
  required int revisionNumber,
  required String name,
  required int restSeconds,
}) {
  return AcceptedProgramRevisionSnapshot(
    assignmentId: assignmentId,
    relationshipId: relationshipId,
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
