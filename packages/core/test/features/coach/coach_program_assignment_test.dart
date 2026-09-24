import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/coach/application/coach_program_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachProgramPayloadBuilder', () {
    final createdAt = DateTime(2026, 9, 24);

    final exercises = <Exercise>[
      Exercise(
        id: 'bench',
        name: 'Press banca',
        muscleGroup: 'Pecho',
        equipment: 'Barra',
      ),
      Exercise(
        id: 'row',
        name: 'Remo',
        muscleGroup: 'Espalda',
        equipment: 'Cable',
      ),
    ];

    final routines = <Routine>[
      Routine(
        id: 'upper-a',
        name: 'Upper A',
        scheduledDays: const [],
        createdAt: createdAt,
        notes: 'Controlar técnica',
        exercises: const [
          RoutineExercise(
            exerciseId: 'bench',
            order: 0,
            targetSets: 3,
            targetRepsMin: 6,
            targetRepsMax: 8,
            restSeconds: 180,
            warmupSets: 2,
          ),
          RoutineExercise(
            exerciseId: 'row',
            order: 1,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 120,
            unilateral: true,
            unilateralTarget: UnilateralTarget.back,
            supersetGroupId: 'pair-1',
          ),
        ],
      ),
    ];

    final program = TrainingProgram(
      id: 'program-local',
      name: 'Upper Lower',
      routineIds: const ['upper-a'],
      createdAt: createdAt,
      startedAt: createdAt,
      durationWeeks: 8,
      trainingWeekdays: const {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
      },
      notes: 'Bloque inicial',
      completions: [
        ProgramCompletion(
          workoutSessionId: 'private-session',
          routineId: 'upper-a',
          completedAt: createdAt,
          rotationIndex: 0,
          programWeek: 1,
        ),
      ],
    );

    test('copies prescription while excluding private workout progress', () {
      final payload = CoachProgramPayloadBuilder.build(
        program: program,
        routines: routines,
        exercises: exercises,
        startsOn: DateTime(2026, 9, 28),
      );

      expect(payload['name'], 'Upper Lower');
      expect(payload['duration_weeks'], 8);
      expect(payload['training_weekdays'], [1, 2, 4]);
      expect(payload['starts_on'], '2026-09-28');

      final routinePayload =
          (payload['routines'] as List).single as Map<String, dynamic>;
      final exercisePayloads =
          routinePayload['exercises'] as List<dynamic>;

      expect(routinePayload['name'], 'Upper A');
      expect(exercisePayloads, hasLength(2));
      expect(
        (exercisePayloads[1] as Map<String, dynamic>)['unilateral'],
        isTrue,
      );
      expect(
        (exercisePayloads[1] as Map<String, dynamic>)['superset_key'],
        'pair-1',
      );

      final serialized = payload.toString().toLowerCase();
      expect(serialized, isNot(contains('private-session')));
      expect(serialized, isNot(contains('completion')));
      expect(serialized, isNot(contains('workout')));
      expect(serialized, isNot(contains('e1rm')));
      expect(serialized, isNot(contains('personalrecord')));
    });

    test('fails when a referenced routine is missing', () {
      expect(
        () => CoachProgramPayloadBuilder.build(
          program: program,
          routines: const <Routine>[],
          exercises: exercises,
          startsOn: createdAt,
        ),
        throwsStateError,
      );
    });

    test('fails when a referenced exercise is missing', () {
      expect(
        () => CoachProgramPayloadBuilder.build(
          program: program,
          routines: routines,
          exercises: const <Exercise>[],
          startsOn: createdAt,
        ),
        throwsStateError,
      );
    });
  });

  group('CoachProgramAssignment', () {
    test('unknown remote status fails closed as archived', () {
      final assignment = CoachProgramAssignment.fromJson({
        'id': 'a1',
        'relationship_id': 'r1',
        'coach_user_id': 'coach',
        'client_user_id': 'client',
        'name': 'Plan',
        'duration_weeks': 4,
        'training_weekdays': [1, 3, 5],
        'starts_on': '2026-09-28',
        'status': 'unexpected',
        'version': 1,
        'created_at': '2026-09-24T10:00:00Z',
        'updated_at': '2026-09-24T10:00:00Z',
        'routines': [],
      });

      expect(assignment.summary.status, AssignedProgramStatus.archived);
      expect(assignment.summary.isClient('client'), isTrue);
      expect(assignment.summary.isCoach('coach'), isTrue);
    });

    test('parses nested normalized prescription transport', () {
      final assignment = CoachProgramAssignment.fromJson({
        'id': 'a1',
        'relationship_id': 'r1',
        'coach_user_id': 'coach',
        'client_user_id': 'client',
        'name': 'Plan',
        'duration_weeks': 4,
        'training_weekdays': [1, 3, 5],
        'starts_on': '2026-09-28',
        'status': 'assigned',
        'version': 1,
        'created_at': '2026-09-24T10:00:00Z',
        'updated_at': '2026-09-24T10:00:00Z',
        'routines': [
          {
            'id': 'routine-cloud',
            'position': 0,
            'name': 'Upper',
            'notes': '',
            'exercises': [
              {
                'id': 'exercise-cloud',
                'position': 0,
                'name': 'Press',
                'muscle_group': 'Pecho',
                'equipment': 'Barra',
                'target_sets': 3,
                'target_reps_min': 6,
                'target_reps_max': 8,
                'rest_seconds': 180,
                'warmup_sets': 2,
                'approach_sets': 0,
                'unilateral': false,
                'unilateral_target': 'other',
              },
            ],
          },
        ],
      });

      expect(assignment.routines, hasLength(1));
      expect(assignment.routines.single.exercises, hasLength(1));
      expect(assignment.routines.single.exercises.single.targetSets, 3);
      expect(assignment.summary.trainingWeekdays, {1, 3, 5});
    });
  });
}
