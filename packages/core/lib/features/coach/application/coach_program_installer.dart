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

class CoachProgramRevisionInstallInspection {
  final String assignmentId;
  final String revisionId;
  final int revisionNumber;
  final String? programId;
  final String? installedRevisionId;
  final int? installedRevisionNumber;
  final bool sameRevisionInstalled;
  final bool upgradesExistingProgram;
  final List<String> localChanges;
  final String localStateToken;

  const CoachProgramRevisionInstallInspection({
    required this.assignmentId,
    required this.revisionId,
    required this.revisionNumber,
    required this.programId,
    required this.installedRevisionId,
    required this.installedRevisionNumber,
    required this.sameRevisionInstalled,
    required this.upgradesExistingProgram,
    required this.localChanges,
    required this.localStateToken,
  });

  bool get requiresOverwriteConfirmation =>
      upgradesExistingProgram && localChanges.isNotEmpty;
}

class CoachProgramLocalChangesException implements Exception {
  final List<String> changes;

  const CoachProgramLocalChangesException(this.changes);

  @override
  String toString() =>
      'El programa importado tiene cambios locales que requieren confirmación.';
}

class CoachProgramInstallStateChangedException implements Exception {
  const CoachProgramInstallStateChangedException();

  @override
  String toString() =>
      'El programa local cambió después de revisarlo. Vuelve a comprobarlo.';
}

class CoachProgramInstaller {
  static const String importsMetadataKey = 'coach_program_imports_v1';
  static const String revisionImportsMetadataKey =
      'coach_program_revision_imports_v2';
  static const String revisionInstallStateMetadataKey =
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
        final current = _readImports();
        if (current[assignmentId] == priorProgramId ||
            current[assignmentId] == null) {
          return;
        }
        current.remove(assignmentId);
        await metadataBox.put(importsMetadataKey, current);
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

  Future<CoachProgramRevisionInstallInspection> inspectAcceptedRevision(
    AcceptedProgramRevisionSnapshot revision,
  ) async {
    _validateAcceptedRevision(revision);

    final baseline = _canonicalRemoteRevision(revision);
    final revisionImports = _readRevisionImports();
    final exactProgramId = _revisionProgramId(
      revisionImports,
      revision.assignmentId,
      revision.revisionId,
    );
    final managed = _managedInstallState(revision.assignmentId);

    if (exactProgramId != null) {
      final exactProgram = programRepository.getById(exactProgramId);
      if (exactProgram != null) {
        if (managed == null ||
            managed.programId != exactProgram.id ||
            managed.revisionId != revision.revisionId) {
          await _writeManagedInstallState(
            revision: revision,
            programId: exactProgram.id,
            baseline: baseline,
          );
        }
        final current = _canonicalLocalProgram(exactProgram);
        return CoachProgramRevisionInstallInspection(
          assignmentId: revision.assignmentId,
          revisionId: revision.revisionId,
          revisionNumber: revision.revisionNumber,
          programId: exactProgram.id,
          installedRevisionId: revision.revisionId,
          installedRevisionNumber: revision.revisionNumber,
          sameRevisionInstalled: true,
          upgradesExistingProgram: false,
          localChanges: List.unmodifiable(
            _summarizeLocalChanges(baseline, current),
          ),
          localStateToken: jsonEncode(current),
        );
      }
    }

    if (managed != null && managed.revisionId == revision.revisionId) {
      final exactProgram = programRepository.getById(managed.programId);
      if (exactProgram != null) {
        await _ensureRevisionImport(
          assignmentId: revision.assignmentId,
          revisionId: revision.revisionId,
          programId: exactProgram.id,
        );
        final current = _canonicalLocalProgram(exactProgram);
        return CoachProgramRevisionInstallInspection(
          assignmentId: revision.assignmentId,
          revisionId: revision.revisionId,
          revisionNumber: revision.revisionNumber,
          programId: exactProgram.id,
          installedRevisionId: revision.revisionId,
          installedRevisionNumber: revision.revisionNumber,
          sameRevisionInstalled: true,
          upgradesExistingProgram: false,
          localChanges: List.unmodifiable(
            _summarizeLocalChanges(managed.baseline, current),
          ),
          localStateToken: jsonEncode(current),
        );
      }
    }

    if (managed != null) {
      final existing = programRepository.getById(managed.programId);
      if (existing != null) {
        final current = _canonicalLocalProgram(existing);
        return CoachProgramRevisionInstallInspection(
          assignmentId: revision.assignmentId,
          revisionId: revision.revisionId,
          revisionNumber: revision.revisionNumber,
          programId: existing.id,
          installedRevisionId: managed.revisionId,
          installedRevisionNumber: managed.revisionNumber,
          sameRevisionInstalled: false,
          upgradesExistingProgram: true,
          localChanges: List.unmodifiable(
            _summarizeLocalChanges(managed.baseline, current),
          ),
          localStateToken: jsonEncode(current),
        );
      }
    }

    return CoachProgramRevisionInstallInspection(
      assignmentId: revision.assignmentId,
      revisionId: revision.revisionId,
      revisionNumber: revision.revisionNumber,
      programId: null,
      installedRevisionId: null,
      installedRevisionNumber: null,
      sameRevisionInstalled: false,
      upgradesExistingProgram: false,
      localChanges: const [],
      localStateToken: '',
    );
  }

  Future<TrainingProgram> installAcceptedRevision(
    AcceptedProgramRevisionSnapshot revision, {
    bool activate = true,
    bool allowOverwriteCustomized = false,
    String? expectedLocalStateToken,
  }) async {
    _validateAcceptedRevision(revision);

    // Bridge an already-installed legacy baseline into revision-aware
    // metadata without duplicating the local program. The baseline is built
    // from the immutable remote snapshot, not from current local state, so
    // prior user edits remain detectable.
    final exact = getInstalledRevision(
      revision.assignmentId,
      revision.revisionId,
    );
    if (exact == null && revision.sourceKind == 'legacy_baseline') {
      final legacyProgramId = _readImports()[revision.assignmentId];
      if (legacyProgramId is String) {
        final legacy = programRepository.getById(legacyProgramId);
        if (legacy != null) {
          await _ensureRevisionImport(
            assignmentId: revision.assignmentId,
            revisionId: revision.revisionId,
            programId: legacy.id,
          );
          await _writeManagedInstallState(
            revision: revision,
            programId: legacy.id,
            baseline: _canonicalRemoteRevision(revision),
          );
          return _maybeActivate(
            legacy,
            activate: activate,
            startsOn: revision.startsOn,
          );
        }
      }
    }

    final inspection = await inspectAcceptedRevision(revision);

    if (inspection.sameRevisionInstalled) {
      final program = inspection.programId == null
          ? null
          : programRepository.getById(inspection.programId!);
      if (program == null) {
        throw StateError('La instalación local de la revisión no existe.');
      }
      return _maybeActivate(
        program,
        activate: activate,
        startsOn: revision.startsOn,
      );
    }

    if (inspection.upgradesExistingProgram) {
      if (expectedLocalStateToken != null &&
          expectedLocalStateToken != inspection.localStateToken) {
        throw const CoachProgramInstallStateChangedException();
      }
      if (inspection.localChanges.isNotEmpty &&
          !allowOverwriteCustomized) {
        throw CoachProgramLocalChangesException(inspection.localChanges);
      }
      final programId = inspection.programId;
      if (programId == null) {
        throw StateError('El programa importado no está disponible.');
      }
      return _upgradeManagedProgram(
        revision,
        programId: programId,
        activate: activate,
      );
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
        await _recordManagedRevision(
          revision: revision,
          programId: programId,
        );
      },
      rollbackImport: () async {
        if (createdProgramId == null) return;
        await _removeManagedProgramMappings(
          assignmentId: revision.assignmentId,
          programId: createdProgramId!,
        );
      },
    );
  }

  Future<TrainingProgram> _upgradeManagedProgram(
    AcceptedProgramRevisionSnapshot revision, {
    required String programId,
    required bool activate,
  }) async {
    final existing = programRepository.getById(programId);
    if (existing == null) {
      throw StateError('El programa importado no está disponible.');
    }

    final priorRevisionImports = metadataBox.get(revisionImportsMetadataKey);
    final priorInstallState =
        metadataBox.get(revisionInstallStateMetadataKey);
    _CreatedRoutineGraph? graph;
    var programWasSaved = false;

    try {
      graph = await _buildRoutineGraph(revision.routines);
      final updated = TrainingProgram(
        id: existing.id,
        name: revision.name,
        routineIds: graph.routineIds,
        createdAt: existing.createdAt,
        startedAt: revision.startsOn,
        durationWeeks: revision.durationWeeks,
        scheduleMode: ProgramScheduleMode.continuous,
        targetSessionsPerWeek: 0,
        trainingWeekdays: Set<int>.from(revision.trainingWeekdays),
        fixedWeekdayRoutineIds: const <int, String>{},
        deloadWeeks: const <int>{},
        nextRotationIndex: 0,
        isActive: existing.isActive,
        isTemplate: false,
        notes: revision.notes,
        // Keep the completion ledger/history. Old routine rows are retained
        // locally so historical references are never destroyed by an upgrade.
        completions: List<ProgramCompletion>.from(existing.completions),
      );
      await programRepository.save(updated);
      programWasSaved = true;

      await _recordManagedRevision(
        revision: revision,
        programId: existing.id,
        replaceMappingsForProgram: true,
      );

      if (activate && !updated.isActive) {
        await programRepository.activate(
          updated.id,
          startedAt: revision.startsOn,
        );
      }

      return programRepository.getById(updated.id) ?? updated;
    } catch (_) {
      if (programWasSaved) {
        try {
          await programRepository.save(existing);
        } catch (_) {}
      }
      try {
        if (priorRevisionImports == null) {
          await metadataBox.delete(revisionImportsMetadataKey);
        } else {
          await metadataBox.put(
            revisionImportsMetadataKey,
            priorRevisionImports,
          );
        }
        if (priorInstallState == null) {
          await metadataBox.delete(revisionInstallStateMetadataKey);
        } else {
          await metadataBox.put(
            revisionInstallStateMetadataKey,
            priorInstallState,
          );
        }
      } catch (_) {}
      if (graph != null) {
        await _cleanupRoutineGraph(graph);
      }
      rethrow;
    }
  }

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

  Future<void> _recordManagedRevision({
    required AcceptedProgramRevisionSnapshot revision,
    required String programId,
    bool replaceMappingsForProgram = false,
  }) async {
    final imports = _readRevisionImports();
    final raw = imports[revision.assignmentId];
    final assignmentImports =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (replaceMappingsForProgram) {
      assignmentImports.removeWhere((_, value) => value == programId);
    }
    assignmentImports[revision.revisionId] = programId;
    imports[revision.assignmentId] = assignmentImports;
    await metadataBox.put(revisionImportsMetadataKey, imports);

    await _writeManagedInstallState(
      revision: revision,
      programId: programId,
      baseline: _canonicalRemoteRevision(revision),
    );
  }

  Future<void> _ensureRevisionImport({
    required String assignmentId,
    required String revisionId,
    required String programId,
  }) async {
    final imports = _readRevisionImports();
    final raw = imports[assignmentId];
    final assignmentImports =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (assignmentImports[revisionId] == programId) return;
    assignmentImports[revisionId] = programId;
    imports[assignmentId] = assignmentImports;
    await metadataBox.put(revisionImportsMetadataKey, imports);
  }

  Future<void> _writeManagedInstallState({
    required AcceptedProgramRevisionSnapshot revision,
    required String programId,
    required Map<String, dynamic> baseline,
  }) async {
    final states = _readManagedInstallStates();
    states[revision.assignmentId] = <String, dynamic>{
      'program_id': programId,
      'revision_id': revision.revisionId,
      'revision_number': revision.revisionNumber,
      'baseline': baseline,
    };
    await metadataBox.put(revisionInstallStateMetadataKey, states);
  }

  Future<void> _removeManagedProgramMappings({
    required String assignmentId,
    required String programId,
  }) async {
    final imports = _readRevisionImports();
    final raw = imports[assignmentId];
    if (raw is Map) {
      final assignmentImports = Map<String, dynamic>.from(raw)
        ..removeWhere((_, value) => value == programId);
      if (assignmentImports.isEmpty) {
        imports.remove(assignmentId);
      } else {
        imports[assignmentId] = assignmentImports;
      }
      await metadataBox.put(revisionImportsMetadataKey, imports);
    }

    final states = _readManagedInstallStates();
    final state = _managedInstallState(assignmentId);
    if (state?.programId == programId) {
      states.remove(assignmentId);
      await metadataBox.put(revisionInstallStateMetadataKey, states);
    }
  }

  _ManagedInstallState? _managedInstallState(String assignmentId) {
    final raw = _readManagedInstallStates()[assignmentId];
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final programId = json['program_id'];
    final revisionId = json['revision_id'];
    final revisionNumber = json['revision_number'];
    final baseline = json['baseline'];
    if (programId is! String ||
        programId.isEmpty ||
        revisionId is! String ||
        revisionId.isEmpty ||
        revisionNumber is! int ||
        revisionNumber < 1 ||
        baseline is! Map) {
      return null;
    }
    return _ManagedInstallState(
      programId: programId,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      baseline: _normalizeMap(baseline),
    );
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
    _CreatedRoutineGraph? graph;
    String? createdProgramId;

    try {
      graph = await _buildRoutineGraph(routines);
      final program = TrainingProgram(
        id: _uuid.v4(),
        name: name,
        routineIds: graph.routineIds,
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
        try {
          await programRepository.delete(createdProgramId);
        } catch (_) {}
      }
      if (graph != null) {
        await _cleanupRoutineGraph(graph);
      }
      rethrow;
    }
  }

  Future<_CreatedRoutineGraph> _buildRoutineGraph(
    List<AssignedRoutineSnapshot> routines,
  ) async {
    final createdExerciseIds = <String>[];
    final createdRoutineIds = <String>[];

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

      return _CreatedRoutineGraph(
        routineIds: List.unmodifiable(routineIds),
        createdRoutineIds: List.unmodifiable(createdRoutineIds),
        createdExerciseIds: List.unmodifiable(createdExerciseIds),
      );
    } catch (_) {
      await _cleanupRoutineGraph(
        _CreatedRoutineGraph(
          routineIds: const [],
          createdRoutineIds: List.unmodifiable(createdRoutineIds),
          createdExerciseIds: List.unmodifiable(createdExerciseIds),
        ),
      );
      rethrow;
    }
  }

  Future<void> _cleanupRoutineGraph(_CreatedRoutineGraph graph) async {
    for (final routineId in graph.createdRoutineIds.reversed) {
      try {
        await routineRepository.deleteRoutine(routineId);
      } catch (_) {}
    }
    for (final exerciseId in graph.createdExerciseIds.reversed) {
      try {
        await exerciseRepository.deleteExercise(exerciseId);
      } catch (_) {}
    }
  }

  void _validateAcceptedRevision(AcceptedProgramRevisionSnapshot revision) {
    if (revision.assignmentId.isEmpty || revision.revisionId.isEmpty) {
      throw ArgumentError('La revisión aceptada no tiene identificadores.');
    }
    if (revision.routines.isEmpty) {
      throw ArgumentError('La revisión aceptada no contiene rutinas.');
    }
  }

  Map<String, dynamic> _canonicalRemoteRevision(
    AcceptedProgramRevisionSnapshot revision,
  ) {
    final routines = List<AssignedRoutineSnapshot>.from(revision.routines)
      ..sort((a, b) => a.position.compareTo(b.position));
    return <String, dynamic>{
      'name': revision.name.trim(),
      'notes': revision.notes,
      'duration_weeks': revision.durationWeeks,
      'schedule_mode': ProgramScheduleMode.continuous.name,
      'target_sessions_per_week': 0,
      'training_weekdays': revision.trainingWeekdays.toList()..sort(),
      'fixed_weekday_routines': const <dynamic>[],
      'deload_weeks': const <int>[],
      'routines': [
        for (final routine in routines)
          <String, dynamic>{
            'name': routine.name.trim(),
            'notes': routine.notes,
            'scheduled_days': const <int>[],
            'exercises': [
              for (final exercise
                  in (List<AssignedExerciseSnapshot>.from(routine.exercises)
                    ..sort((a, b) => a.position.compareTo(b.position))))
                _canonicalRemoteExercise(exercise),
            ],
          },
      ],
    };
  }

  Map<String, dynamic> _canonicalRemoteExercise(
    AssignedExerciseSnapshot exercise,
  ) =>
      <String, dynamic>{
        'exercise_key': _exerciseKey(
          exercise.name,
          exercise.muscleGroup,
          exercise.equipment,
        ),
        'order': exercise.position,
        'target_sets': exercise.targetSets,
        'target_reps_min': exercise.targetRepsMin,
        'target_reps_max': exercise.targetRepsMax,
        'rest_seconds': exercise.restSeconds,
        'warmup_sets': exercise.warmupSets,
        'approach_sets': exercise.approachSets,
        'warmup_rest_seconds': exercise.warmupRestSeconds,
        'approach_rest_seconds': exercise.approachRestSeconds,
        'phase': RoutineExercisePhase.main.name,
        'unilateral': exercise.unilateral,
        'unilateral_target': exercise.unilateralTarget,
        'preparation_unilateral': exercise.preparationUnilateral,
        'unilateral_side_rest_seconds':
            exercise.unilateralSideRestSeconds,
        'preferred_unilateral_start_side':
            exercise.preferredUnilateralStartSide?.name,
        'superset_group_id': exercise.supersetKey,
      };

  Map<String, dynamic> _canonicalLocalProgram(TrainingProgram program) {
    final routinesById = <String, Routine>{
      for (final routine in routineRepository.getAllRoutines())
        routine.id: routine,
    };
    final fixed = program.fixedWeekdayRoutineIds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return <String, dynamic>{
      'name': program.name.trim(),
      'notes': program.notes,
      'duration_weeks': program.durationWeeks,
      'schedule_mode': program.scheduleMode.name,
      'target_sessions_per_week': program.targetSessionsPerWeek,
      'training_weekdays': program.trainingWeekdays.toList()..sort(),
      'fixed_weekday_routines': [
        for (final entry in fixed)
          <String, dynamic>{
            'day': entry.key,
            'routine_position': program.routineIds.indexOf(entry.value),
          },
      ],
      'deload_weeks': program.deloadWeeks.toList()..sort(),
      'routines': [
        for (final routineId in program.routineIds)
          _canonicalLocalRoutine(routinesById[routineId], routineId),
      ],
    };
  }

  Map<String, dynamic> _canonicalLocalRoutine(
    Routine? routine,
    String routineId,
  ) {
    if (routine == null) {
      return <String, dynamic>{
        'missing_routine': routineId,
      };
    }
    final exercises = List<RoutineExercise>.from(routine.exercises)
      ..sort((a, b) => a.order.compareTo(b.order));
    return <String, dynamic>{
      'name': routine.name.trim(),
      'notes': routine.notes,
      'scheduled_days': List<int>.from(routine.scheduledDays)..sort(),
      'exercises': [
        for (final exercise in exercises) _canonicalLocalExercise(exercise),
      ],
    };
  }

  Map<String, dynamic> _canonicalLocalExercise(RoutineExercise exercise) {
    final model = exerciseRepository.getExerciseById(exercise.exerciseId);
    return <String, dynamic>{
      'exercise_key': model == null
          ? 'missing:${exercise.exerciseId}'
          : _exerciseKey(model.name, model.muscleGroup, model.equipment),
      'order': exercise.order,
      'target_sets': exercise.targetSets,
      'target_reps_min': exercise.targetRepsMin,
      'target_reps_max': exercise.targetRepsMax,
      'rest_seconds': exercise.restSeconds,
      'warmup_sets': exercise.warmupSets,
      'approach_sets': exercise.approachSets,
      'warmup_rest_seconds': exercise.warmupRestSeconds,
      'approach_rest_seconds': exercise.approachRestSeconds,
      'phase': exercise.phase.name,
      'unilateral': exercise.unilateral,
      'unilateral_target': exercise.unilateralTarget.name,
      'preparation_unilateral': exercise.preparationUnilateral,
      'unilateral_side_rest_seconds': exercise.unilateralSideRestSeconds,
      'preferred_unilateral_start_side':
          exercise.preferredUnilateralStartSide?.name,
      'superset_group_id': exercise.supersetGroupId,
    };
  }

  List<String> _summarizeLocalChanges(
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) {
    final changes = <String>[];

    if (!_sameJson(
      _pick(baseline, ['name', 'notes', 'duration_weeks']),
      _pick(current, ['name', 'notes', 'duration_weeks']),
    )) {
      changes.add('Nombre, notas o duración del programa');
    }
    if (!_sameJson(
      _pick(baseline, [
        'schedule_mode',
        'target_sessions_per_week',
        'training_weekdays',
        'fixed_weekday_routines',
        'deload_weeks',
      ]),
      _pick(current, [
        'schedule_mode',
        'target_sessions_per_week',
        'training_weekdays',
        'fixed_weekday_routines',
        'deload_weeks',
      ]),
    )) {
      changes.add('Calendario, frecuencia o semanas de descarga');
    }

    final baselineRoutines = _mapList(baseline['routines']);
    final currentRoutines = _mapList(current['routines']);
    if (baselineRoutines.length != currentRoutines.length) {
      changes.add('Cantidad u orden de rutinas');
    }

    final count = baselineRoutines.length < currentRoutines.length
        ? baselineRoutines.length
        : currentRoutines.length;
    for (var index = 0; index < count; index++) {
      final before = baselineRoutines[index];
      final now = currentRoutines[index];
      final label =
          (now['name'] ?? before['name'] ?? 'Rutina ${index + 1}').toString();

      if (!_sameJson(
        _pick(before, ['name', 'notes', 'scheduled_days']),
        _pick(now, ['name', 'notes', 'scheduled_days']),
      )) {
        changes.add('$label: nombre, notas o días');
      }

      final beforeExercises = _mapList(before['exercises']);
      final nowExercises = _mapList(now['exercises']);
      if (beforeExercises.length != nowExercises.length) {
        changes.add('$label: ejercicios u orden');
        continue;
      }

      var structureChanged = false;
      var prescriptionChanged = false;
      for (var exerciseIndex = 0;
          exerciseIndex < beforeExercises.length;
          exerciseIndex++) {
        final beforeExercise = beforeExercises[exerciseIndex];
        final nowExercise = nowExercises[exerciseIndex];
        if (!_sameJson(
          _pick(beforeExercise, [
            'exercise_key',
            'order',
            'phase',
            'superset_group_id',
          ]),
          _pick(nowExercise, [
            'exercise_key',
            'order',
            'phase',
            'superset_group_id',
          ]),
        )) {
          structureChanged = true;
        }
        if (!_sameJson(
          _pick(beforeExercise, [
            'target_sets',
            'target_reps_min',
            'target_reps_max',
            'rest_seconds',
            'warmup_sets',
            'approach_sets',
            'warmup_rest_seconds',
            'approach_rest_seconds',
            'unilateral',
            'unilateral_target',
            'preparation_unilateral',
            'unilateral_side_rest_seconds',
            'preferred_unilateral_start_side',
          ]),
          _pick(nowExercise, [
            'target_sets',
            'target_reps_min',
            'target_reps_max',
            'rest_seconds',
            'warmup_sets',
            'approach_sets',
            'warmup_rest_seconds',
            'approach_rest_seconds',
            'unilateral',
            'unilateral_target',
            'preparation_unilateral',
            'unilateral_side_rest_seconds',
            'preferred_unilateral_start_side',
          ]),
        )) {
          prescriptionChanged = true;
        }
      }
      if (structureChanged) {
        changes.add('$label: ejercicios, orden, fase o superseries');
      }
      if (prescriptionChanged) {
        changes.add(
          '$label: series, repeticiones, descansos o configuración unilateral',
        );
      }
    }

    return changes.toSet().take(8).toList(growable: false);
  }

  Map<String, dynamic> _pick(
    Map<String, dynamic> source,
    List<String> keys,
  ) =>
      <String, dynamic>{
        for (final key in keys) key: source[key],
      };

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(_normalizeMap)
        .toList(growable: false);
  }

  bool _sameJson(Object? left, Object? right) =>
      jsonEncode(left) == jsonEncode(right);

  Map<String, dynamic> _normalizeMap(Map raw) => <String, dynamic>{
        for (final entry in raw.entries)
          entry.key.toString(): _normalizeJsonValue(entry.value),
      };

  Object? _normalizeJsonValue(Object? value) {
    if (value is Map) return _normalizeMap(value);
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
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

  Map<String, dynamic> _readManagedInstallStates() {
    final raw = metadataBox.get(revisionInstallStateMetadataKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
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

class _ManagedInstallState {
  final String programId;
  final String revisionId;
  final int revisionNumber;
  final Map<String, dynamic> baseline;

  const _ManagedInstallState({
    required this.programId,
    required this.revisionId,
    required this.revisionNumber,
    required this.baseline,
  });
}

class _CreatedRoutineGraph {
  final List<String> routineIds;
  final List<String> createdRoutineIds;
  final List<String> createdExerciseIds;

  const _CreatedRoutineGraph({
    required this.routineIds,
    required this.createdRoutineIds,
    required this.createdExerciseIds,
  });
}
