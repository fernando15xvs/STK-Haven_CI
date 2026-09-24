import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/exercises/data/exercise_repository.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class CoachProgramInstaller {
  static const String importsMetadataKey = 'coach_program_imports_v1';
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
      if (prior != null) return prior;
    }

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
      final routines = List<AssignedRoutineSnapshot>.from(assignment.routines)
        ..sort((a, b) => a.position.compareTo(b.position));

      for (final assignedRoutine in routines) {
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
              unilateral: prescription.unilateral,
              unilateralTarget:
                  _unilateralTarget(prescription.unilateralTarget),
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
        name: assignment.summary.name,
        routineIds: routineIds,
        createdAt: DateTime.now(),
        startedAt: assignment.summary.startsOn,
        durationWeeks: assignment.summary.durationWeeks,
        trainingWeekdays:
            Set<int>.from(assignment.summary.trainingWeekdays),
        nextRotationIndex: 0,
        isActive: false,
        notes: assignment.notes,
      );
      createdProgramId = program.id;
      await programRepository.save(program);

      if (activate) {
        await programRepository.activate(
          program.id,
          startedAt: assignment.summary.startsOn,
        );
      }

      imports[assignmentId] = program.id;
      await metadataBox.put(importsMetadataKey, imports);

      return programRepository.getById(program.id) ?? program;
    } catch (_) {
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
