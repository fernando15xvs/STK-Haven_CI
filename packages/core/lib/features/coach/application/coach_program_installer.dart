import 'dart:convert';

import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
import 'package:core/features/exercises/data/exercise_repository.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class CoachProgramInstallAssessment {
  final String assignmentId;
  final String targetRevisionId;
  final int targetRevisionNumber;
  final String? installedRevisionId;
  final int? installedRevisionNumber;
  final String? installedProgramId;
  final bool targetAlreadyInstalled;
  final List<String> localChanges;

  const CoachProgramInstallAssessment({
    required this.assignmentId,
    required this.targetRevisionId,
    required this.targetRevisionNumber,
    required this.installedRevisionId,
    required this.installedRevisionNumber,
    required this.installedProgramId,
    required this.targetAlreadyInstalled,
    required this.localChanges,
  });

  bool get hasLocalChanges => localChanges.isNotEmpty;

  bool get requiresLocalChangeConfirmation =>
      !targetAlreadyInstalled &&
      installedProgramId != null &&
      localChanges.isNotEmpty;
}

class CoachProgramLocalChangesException implements Exception {
  final CoachProgramInstallAssessment assessment;

  const CoachProgramLocalChangesException(this.assessment);

  @override
  String toString() =>
      'La copia local del programa tiene cambios que requieren confirmación.';
}

class CoachProgramInstaller {
  static const String importsMetadataKey = 'coach_program_imports_v1';
  static const String revisionImportsMetadataKey =
      'coach_program_revision_imports_v2';
  static const String managedRevisionMetadataKey =
      'coach_program_revision_install_state_v3';
  static const Uuid _uuid = Uuid();

  final ExerciseRepository exerciseRepository;
  final RoutineRepository routineRepository;
  final TrainingProgramRepository programRepository;
  final Box<dynamic> metadataBox;

  CoachProgramInstaller({
    required this.exerciseRepository,
    required this.routineRepository,
    required this.programRepository,
    required this.metadataBox,
  });

  Future<TrainingProgram> install(
    CoachProgramAssignment assignment, {
    bool activate = true,
  }) async {
    final assignmentId = assignment.summary.id;
    if (assignmentId.isEmpty) {
      throw ArgumentError('La asignación no tiene id.');
    }
    if (assignment.routines.isEmpty) {
      throw ArgumentError('El programa asignado no contiene rutinas.');
    }

    final imports = _readImports();
    final priorProgramId = imports[assignmentId];
    if (priorProgramId is String) {
      final prior = programRepository.getById(priorProgramId);
      if (prior != null) {
        return _maybeActivate(
          prior,
          activate: activate,
          startsOn: assignment.summary.startsOn,
        );
      }
    }

    return _createProgram(
      name: assignment.summary.name,
      notes: assignment.notes,
      startsOn: assignment.summary.startsOn,
      durationWeeks: assignment.summary.durationWeeks,
      trainingWeekdays: assignment.summary.trainingWeekdays,
      routines: assignment.routines,
      activate: activate,
      recordImport: (programId) async {
        imports[assignmentId] = programId;
        await metadataBox.put(importsMetadataKey, imports);
      },
      rollbackImport: () async {
        final currentImports = _readImports();
        if (currentImports[assignmentId] == priorProgramId ||
            currentImports[assignmentId] == null) {
          return;
        }
        currentImports.remove(assignmentId);
        await metadataBox.put(importsMetadataKey, currentImports);
      },
    );
  }

  TrainingProgram? getInstalledRevision(
    String assignmentId,
    String revisionId,
  ) {
    final programId = _revisionProgramId(
      _readRevisionImports(),
      assignmentId,
      revisionId,
    );
    if (programId == null) return null;
    return programRepository.getById(programId);
  }

  Future<CoachProgramInstallAssessment> assessAcceptedRevision(
    AcceptedProgramRevisionSnapshot revision,
  ) async {
    _validateRevision(revision);

    final exact = getInstalledRevision(
      revision.assignmentId,
      revision.revisionId,
    );
    if (exact != null) {
      await _ensureManagedStateForExactRevision(revision, exact);
      return CoachProgramInstallAssessment(
        assignmentId: revision.assignmentId,
        targetRevisionId: revision.revisionId,
        targetRevisionNumber: revision.revisionNumber,
        installedRevisionId: revision.revisionId,
        installedRevisionNumber: revision.revisionNumber,
        installedProgramId: exact.id,
        targetAlreadyInstalled: true,
        localChanges: const [],
      );
    }

    final managed = _managedStateForAssignment(revision.assignmentId);
    if (managed != null) {
      final programId = managed['program_id'];
      final revisionId = managed['revision_id'];
      final revisionNumber = managed['revision_number'];
      final baseline = managed['baseline'];
      if (programId is String &&
          programId.isNotEmpty &&
          revisionId is String &&
          revisionId.isNotEmpty &&
          revisionNumber is int &&
          baseline is Map) {
        final program = programRepository.getById(programId);
        if (program == null) {
          return CoachProgramInstallAssessment(
            assignmentId: revision.assignmentId,
            targetRevisionId: revision.revisionId,
            targetRevisionNumber: revision.revisionNumber,
            installedRevisionId: revisionId,
            installedRevisionNumber: revisionNumber,
            installedProgramId: programId,
            targetAlreadyInstalled: false,
            localChanges: const [
              'La copia local administrada anteriormente ya no existe.',
            ],
          );
        }

        final current = _snapshotLocalProgram(program.id);
        final changes = _describeLocalChanges(
          Map<String, dynamic>.from(baseline),
          current,
        );
        return CoachProgramInstallAssessment(
          assignmentId: revision.assignmentId,
          targetRevisionId: revision.revisionId,
          targetRevisionNumber: revision.revisionNumber,
          installedRevisionId: revisionId,
          installedRevisionNumber: revisionNumber,
          installedProgramId: program.id,
          targetAlreadyInstalled: false,
          localChanges: List.unmodifiable(changes),
        );
      }
    }

    final legacyProgram = _legacyRevisionProgram(revision.assignmentId);
    if (legacyProgram != null) {
      return CoachProgramInstallAssessment(
        assignmentId: revision.assignmentId,
        targetRevisionId: revision.revisionId,
        targetRevisionNumber: revision.revisionNumber,
        installedRevisionId: null,
        installedRevisionNumber: null,
        installedProgramId: legacyProgram.id,
        targetAlreadyInstalled: false,
        localChanges: const [
          'La instalación anterior usa metadata heredada; no se puede '
              'verificar con seguridad si fue modificada localmente.',
        ],
      );
    }

    return CoachProgramInstallAssessment(
      assignmentId: revision.assignmentId,
      targetRevisionId: revision.revisionId,
      targetRevisionNumber: revision.revisionNumber,
      installedRevisionId: null,
      installedRevisionNumber: null,
      installedProgramId: null,
      targetAlreadyInstalled: false,
      localChanges: const [],
    );
  }

  Future<TrainingProgram> installAcceptedRevision(
    AcceptedProgramRevisionSnapshot revision, {
    bool activate = true,
    bool confirmLocalChanges = false,
  }) async {
    _validateRevision(revision);

    final assessment = await assessAcceptedRevision(revision);
    if (assessment.targetAlreadyInstalled) {
      final prior = programRepository.getById(assessment.installedProgramId!);
      if (prior == null) {
        throw StateError('La revisión instalada ya no existe localmente.');
      }
      return _maybeActivate(
        prior,
        activate: activate,
        startsOn: revision.startsOn,
      );
    }
    if (assessment.requiresLocalChangeConfirmation &&
        !confirmLocalChanges) {
      throw CoachProgramLocalChangesException(assessment);
    }

    final revisionImports = _readRevisionImports();
    final managedImports = _readManagedStates();
    final priorManaged = managedImports[revision.assignmentId];

    // Bridge an already-installed legacy baseline into the revision-aware
    // metadata without duplicating the local program.
    if (revision.sourceKind == 'legacy_baseline') {
      final legacyProgramId = _readImports()[revision.assignmentId];
      if (legacyProgramId is String) {
        final legacy = programRepository.getById(legacyProgramId);
        if (legacy != null) {
          await _recordRevisionImport(
            revisionImports,
            assignmentId: revision.assignmentId,
            revisionId: revision.revisionId,
            programId: legacy.id,
          );
          await _recordManagedState(
            managedImports,
            revision: revision,
            programId: legacy.id,
          );
          return _maybeActivate(
            legacy,
            activate: activate,
            startsOn: revision.startsOn,
          );
        }
      }
    }

    String? createdProgramId;
    return _createProgram(
      name: revision.name,
      notes: revision.notes,
      startsOn: revision.startsOn,
      durationWeeks: revision.durationWeeks,
      trainingWeekdays: revision.trainingWeekdays,
      routines: revision.routines,
      activate: activate,
      recordImport: (programId) async {
        createdProgramId = programId;
        await _recordRevisionImport(
          revisionImports,
          assignmentId: revision.assignmentId,
          revisionId: revision.revisionId,
          programId: programId,
        );
        await _recordManagedState(
          managedImports,
          revision: revision,
          programId: programId,
        );
      },
      rollbackImport: () async {
        if (createdProgramId == null) return;

        final currentRevisionImports = _readRevisionImports();
        final mapped = _revisionProgramId(
          currentRevisionImports,
          revision.assignmentId,
          revision.revisionId,
        );
        if (mapped == createdProgramId) {
          final assignmentImports =
              currentRevisionImports[revision.assignmentId];
          if (assignmentImports is Map) {
            final nested = Map<String, dynamic>.from(assignmentImports);
            nested.remove(revision.revisionId);
            if (nested.isEmpty) {
              currentRevisionImports.remove(revision.assignmentId);
            } else {
              currentRevisionImports[revision.assignmentId] = nested;
            }
            await metadataBox.put(
              revisionImportsMetadataKey,
              currentRevisionImports,
            );
          }
        }

        final currentManaged = _readManagedStates();
        final state = currentManaged[revision.assignmentId];
        if (state is Map && state['program_id'] == createdProgramId) {
          if (priorManaged == null) {
            currentManaged.remove(revision.assignmentId);
          } else {
            currentManaged[revision.assignmentId] = priorManaged;
          }
          await metadataBox.put(managedRevisionMetadataKey, currentManaged);
        }
      },
    );
  }

  void _validateRevision(AcceptedProgramRevisionSnapshot revision) {
    if (revision.assignmentId.isEmpty || revision.revisionId.isEmpty) {
      throw ArgumentError('La revisión aceptada no tiene identificadores.');
    }
    if (revision.routines.isEmpty) {
      throw ArgumentError('La revisión aceptada no contiene rutinas.');
    }
  }

  Future<void> _ensureManagedStateForExactRevision(
    AcceptedProgramRevisionSnapshot revision,
    TrainingProgram program,
  ) async {
    final managed = _managedStateForAssignment(revision.assignmentId);
    if (managed != null &&
        managed['program_id'] == program.id &&
        managed['revision_id'] == revision.revisionId &&
        managed['baseline'] is Map) {
      return;
    }
    final states = _readManagedStates();
    await _recordManagedState(
      states,
      revision: revision,
      programId: program.id,
    );
  }

  TrainingProgram? _legacyRevisionProgram(String assignmentId) {
    final raw = _readRevisionImports()[assignmentId];
    if (raw is! Map) return null;

    final programs = <TrainingProgram>[];
    for (final value in raw.values) {
      if (value is! String || value.isEmpty) continue;
      final program = programRepository.getById(value);
      if (program != null) programs.add(program);
    }
    if (programs.isEmpty) return null;

    for (final program in programs) {
      if (program.isActive) return program;
    }
    programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return programs.first;
  }

  Map<String, dynamic>? _managedStateForAssignment(String assignmentId) {
    final value = _readManagedStates()[assignmentId];
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  Future<void> _recordManagedState(
    Map<String, dynamic> states, {
    required AcceptedProgramRevisionSnapshot revision,
    required String programId,
  }) async {
    states[revision.assignmentId] = <String, dynamic>{
      'program_id': programId,
      'revision_id': revision.revisionId,
      'revision_number': revision.revisionNumber,
      'baseline': _snapshotLocalProgram(programId),
    };
    await metadataBox.put(managedRevisionMetadataKey, states);
  }

  Map<String, dynamic> _snapshotLocalProgram(String programId) {
    final program = programRepository.getById(programId);
    if (program == null) {
      throw StateError('El programa local importado no existe.');
    }

    final routinesById = <String, Routine>{
      for (final routine in routineRepository.getAllRoutines())
        routine.id: routine,
    };
    final exercisesById = <String, Exercise>{
      for (final exercise in exerciseRepository.getAllExercises())
        exercise.id: exercise,
    };

    return <String, dynamic>{
      'program': <String, dynamic>{
        'name': program.name,
        'routine_ids': List<String>.from(program.routineIds),
        'duration_weeks': program.durationWeeks,
        'schedule_mode': program.scheduleMode.name,
        'target_sessions_per_week': program.targetSessionsPerWeek,
        'training_weekdays': program.trainingWeekdays.toList()..sort(),
        'fixed_weekday_routine_ids': <String, dynamic>{
          for (final key in (program.fixedWeekdayRoutineIds.keys.toList()
                ..sort()))
            key.toString(): program.fixedWeekdayRoutineIds[key],
        },
        'deload_weeks': program.deloadWeeks.toList()..sort(),
        'notes': program.notes,
      },
      'routines': <Map<String, dynamic>>[
        for (final routineId in program.routineIds)
          _snapshotRoutine(
            routineId,
            routinesById[routineId],
            exercisesById,
          ),
      ],
    };
  }

  Map<String, dynamic> _snapshotRoutine(
    String routineId,
    Routine? routine,
    Map<String, Exercise> exercisesById,
  ) {
    if (routine == null) {
      return <String, dynamic>{
        'id': routineId,
        'missing': true,
      };
    }
    final ordered = List<RoutineExercise>.from(routine.exercises)
      ..sort((a, b) => a.order.compareTo(b.order));
    return <String, dynamic>{
      'id': routine.id,
      'missing': false,
      'name': routine.name,
      'scheduled_days': List<int>.from(routine.scheduledDays)..sort(),
      'notes': routine.notes,
      'exercises': <Map<String, dynamic>>[
        for (final item in ordered)
          _snapshotRoutineExercise(item, exercisesById[item.exerciseId]),
      ],
    };
  }

  Map<String, dynamic> _snapshotRoutineExercise(
    RoutineExercise item,
    Exercise? exercise,
  ) {
    return <String, dynamic>{
      'exercise_id': item.exerciseId,
      'exercise_missing': exercise == null,
      'exercise_name': exercise?.name,
      'muscle_group': exercise?.muscleGroup,
      'equipment': exercise?.equipment,
      'order': item.order,
      'target_sets': item.targetSets,
      'target_reps_min': item.targetRepsMin,
      'target_reps_max': item.targetRepsMax,
      'rest_seconds': item.restSeconds,
      'warmup_sets': item.warmupSets,
      'approach_sets': item.approachSets,
      'warmup_rest_seconds': item.warmupRestSeconds,
      'approach_rest_seconds': item.approachRestSeconds,
      'phase': item.phase.name,
      'unilateral': item.unilateral,
      'unilateral_target': item.unilateralTarget.name,
      'preparation_unilateral': item.preparationUnilateral,
      'unilateral_side_rest_seconds': item.unilateralSideRestSeconds,
      'preferred_unilateral_start_side':
          item.preferredUnilateralStartSide?.name,
      'superset_group_id': item.supersetGroupId,
    };
  }

  List<String> _describeLocalChanges(
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) {
    final changes = <String>[];
    final baseProgram = _map(baseline['program']);
    final currentProgram = _map(current['program']);

    if (baseProgram == null || currentProgram == null) {
      return const ['No se pudo validar la estructura del programa local.'];
    }

    if (baseProgram['name'] != currentProgram['name'] ||
        baseProgram['notes'] != currentProgram['notes']) {
      changes.add('Cambió el nombre o las notas del programa.');
    }

    if (!_sameJson(
          baseProgram['duration_weeks'],
          currentProgram['duration_weeks'],
        ) ||
        !_sameJson(
          baseProgram['schedule_mode'],
          currentProgram['schedule_mode'],
        ) ||
        !_sameJson(
          baseProgram['target_sessions_per_week'],
          currentProgram['target_sessions_per_week'],
        ) ||
        !_sameJson(
          baseProgram['training_weekdays'],
          currentProgram['training_weekdays'],
        ) ||
        !_sameJson(
          baseProgram['fixed_weekday_routine_ids'],
          currentProgram['fixed_weekday_routine_ids'],
        ) ||
        !_sameJson(
          baseProgram['deload_weeks'],
          currentProgram['deload_weeks'],
        )) {
      changes.add('Cambió la programación o frecuencia del programa.');
    }

    if (!_sameJson(
      baseProgram['routine_ids'],
      currentProgram['routine_ids'],
    )) {
      changes.add('Se añadieron, eliminaron o reordenaron rutinas.');
    }

    final baseRoutines = _listOfMaps(baseline['routines']);
    final currentRoutines = _listOfMaps(current['routines']);
    final currentById = <String, Map<String, dynamic>>{
      for (final item in currentRoutines)
        if (item['id'] is String) item['id'] as String: item,
    };

    for (final baseRoutine in baseRoutines) {
      final id = baseRoutine['id'];
      if (id is! String) continue;
      final currentRoutine = currentById[id];
      final label =
          (baseRoutine['name']?.toString().trim().isNotEmpty ?? false)
              ? '«${baseRoutine['name']}»'
              : 'local';
      if (currentRoutine == null || currentRoutine['missing'] == true) {
        changes.add('La rutina $label ya no existe.');
        continue;
      }

      if (baseRoutine['name'] != currentRoutine['name'] ||
          baseRoutine['notes'] != currentRoutine['notes'] ||
          !_sameJson(
            baseRoutine['scheduled_days'],
            currentRoutine['scheduled_days'],
          )) {
        changes.add('Cambió el nombre, notas o días de la rutina $label.');
      }
      if (!_sameJson(
        baseRoutine['exercises'],
        currentRoutine['exercises'],
      )) {
        changes.add('Cambió la prescripción o ejercicios de la rutina $label.');
      }
    }

    return changes.toSet().take(12).toList(growable: false);
  }

  Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  bool _sameJson(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  Future<TrainingProgram> _maybeActivate(
    TrainingProgram program, {
    required bool activate,
    required DateTime startsOn,
  }) async {
    if (activate && !program.isActive) {
      await programRepository.activate(program.id, startedAt: startsOn);
      return programRepository.getById(program.id) ?? program;
    }
    return program;
  }

  Future<void> _recordRevisionImport(
    Map<String, dynamic> imports, {
    required String assignmentId,
    required String revisionId,
    required String programId,
  }) async {
    final raw = imports[assignmentId];
    final assignmentImports =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    assignmentImports[revisionId] = programId;
    imports[assignmentId] = assignmentImports;
    await metadataBox.put(revisionImportsMetadataKey, imports);
  }

  String? _revisionProgramId(
    Map<String, dynamic> imports,
    String assignmentId,
    String revisionId,
  ) {
    final raw = imports[assignmentId];
    if (raw is! Map) return null;
    final value = raw[revisionId];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<TrainingProgram> _createProgram({
    required String name,
    required String notes,
    required DateTime startsOn,
    required int durationWeeks,
    required Set<int> trainingWeekdays,
    required List<AssignedRoutineSnapshot> routines,
    required bool activate,
    required Future<void> Function(String programId) recordImport,
    required Future<void> Function() rollbackImport,
  }) async {
    final createdExerciseIds = <String>[];
    final createdRoutineIds = <String>[];
    String? createdProgramId;

    try {
      final exerciseByKey = <String, Exercise>{
        for (final exercise in exerciseRepository.getAllExercises())
          _exerciseKey(
            exercise.name,
            exercise.muscleGroup,
            exercise.equipment,
          ): exercise,
      };

      final routineIds = <String>[];
      final orderedRoutines = List<AssignedRoutineSnapshot>.from(routines)
        ..sort((a, b) => a.position.compareTo(b.position));

      for (final assignedRoutine in orderedRoutines) {
        final localRoutineId = _uuid.v4();
        final localExercises = <RoutineExercise>[];
        final prescriptions =
            List<AssignedExerciseSnapshot>.from(assignedRoutine.exercises)
              ..sort((a, b) => a.position.compareTo(b.position));

        if (prescriptions.isEmpty) {
          throw StateError(
            'La rutina ${assignedRoutine.name} no contiene ejercicios.',
          );
        }

        for (final prescription in prescriptions) {
          final key = _exerciseKey(
            prescription.name,
            prescription.muscleGroup,
            prescription.equipment,
          );
          var exercise = exerciseByKey[key];
          if (exercise == null) {
            exercise = Exercise(
              id: 'coach_${_uuid.v4()}',
              name: prescription.name,
              muscleGroup: prescription.muscleGroup,
              equipment: prescription.equipment,
            );
            await exerciseRepository.addExercise(exercise);
            createdExerciseIds.add(exercise.id);
            exerciseByKey[key] = exercise;
          }

          localExercises.add(
            RoutineExercise(
              exerciseId: exercise.id,
              order: prescription.position,
              targetSets: prescription.targetSets,
              targetRepsMin: prescription.targetRepsMin,
              targetRepsMax: prescription.targetRepsMax,
              restSeconds: prescription.restSeconds,
              warmupSets: prescription.warmupSets,
              approachSets: prescription.approachSets,
              warmupRestSeconds: prescription.warmupRestSeconds,
              approachRestSeconds: prescription.approachRestSeconds,
              unilateral: prescription.unilateral,
              unilateralTarget:
                  _unilateralTarget(prescription.unilateralTarget),
              preparationUnilateral: prescription.preparationUnilateral,
              unilateralSideRestSeconds:
                  prescription.unilateralSideRestSeconds,
              preferredUnilateralStartSide:
                  prescription.preferredUnilateralStartSide,
              supersetGroupId: prescription.supersetKey,
            ),
          );
        }

        final routine = Routine(
          id: localRoutineId,
          name: assignedRoutine.name,
          scheduledDays: const <int>[],
          exercises: localExercises,
          createdAt: DateTime.now(),
          notes: assignedRoutine.notes,
        );
        await routineRepository.addRoutine(routine);
        createdRoutineIds.add(localRoutineId);
        routineIds.add(localRoutineId);
      }

      final program = TrainingProgram(
        id: _uuid.v4(),
        name: name,
        routineIds: routineIds,
        createdAt: DateTime.now(),
        startedAt: startsOn,
        durationWeeks: durationWeeks,
        trainingWeekdays: Set<int>.from(trainingWeekdays),
        nextRotationIndex: 0,
        isActive: false,
        notes: notes,
      );
      createdProgramId = program.id;
      await programRepository.save(program);
      await recordImport(program.id);

      if (activate) {
        await programRepository.activate(
          program.id,
          startedAt: startsOn,
        );
      }

      return programRepository.getById(program.id) ?? program;
    } catch (_) {
      try {
        await rollbackImport();
      } catch (_) {}
      if (createdProgramId != null) {
        await programRepository.delete(createdProgramId);
      }
      for (final routineId in createdRoutineIds.reversed) {
        await routineRepository.deleteRoutine(routineId);
      }
      for (final exerciseId in createdExerciseIds.reversed) {
        await exerciseRepository.deleteExercise(exerciseId);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _readImports() {
    final raw = metadataBox.get(importsMetadataKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _readRevisionImports() {
    final raw = metadataBox.get(revisionImportsMetadataKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _readManagedStates() {
    final raw = metadataBox.get(managedRevisionMetadataKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  String _exerciseKey(
    String name,
    String muscleGroup,
    String equipment,
  ) {
    return [
      name.trim().toLowerCase(),
      muscleGroup.trim().toLowerCase(),
      equipment.trim().toLowerCase(),
    ].join('|');
  }

  UnilateralTarget _unilateralTarget(String raw) {
    for (final target in UnilateralTarget.values) {
      if (target.name == raw) return target;
    }
    return UnilateralTarget.other;
  }
}
