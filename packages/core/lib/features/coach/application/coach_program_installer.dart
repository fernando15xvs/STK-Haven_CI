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

class CoachProgramInstaller {
  static const String importsMetadataKey = 'coach_program_imports_v1';
  static const String revisionImportsMetadataKey =
      'coach_program_revision_imports_v2';
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

  Future<TrainingProgram> installAcceptedRevision(
    AcceptedProgramRevisionSnapshot revision, {
    bool activate = true,
  }) async {
    if (revision.assignmentId.isEmpty || revision.revisionId.isEmpty) {
      throw ArgumentError('La revisión aceptada no tiene identificadores.');
    }
    if (revision.routines.isEmpty) {
      throw ArgumentError('La revisión aceptada no contiene rutinas.');
    }

    final revisionImports = _readRevisionImports();
    final priorProgramId = _revisionProgramId(
      revisionImports,
      revision.assignmentId,
      revision.revisionId,
    );
    if (priorProgramId != null) {
      final prior = programRepository.getById(priorProgramId);
      if (prior != null) {
        return _maybeActivate(
          prior,
          activate: activate,
          startsOn: revision.startsOn,
        );
      }
    }

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
      },
      rollbackImport: () async {
        if (createdProgramId == null) return;
        final current = _readRevisionImports();
        final mapped = _revisionProgramId(
          current,
          revision.assignmentId,
          revision.revisionId,
        );
        if (mapped != createdProgramId) return;
        final assignmentImports = current[revision.assignmentId];
        if (assignmentImports is Map) {
          final nested = Map<String, dynamic>.from(assignmentImports);
          nested.remove(revision.revisionId);
          if (nested.isEmpty) {
            current.remove(revision.assignmentId);
          } else {
            current[revision.assignmentId] = nested;
          }
          await metadataBox.put(revisionImportsMetadataKey, current);
        }
      },
    );
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
