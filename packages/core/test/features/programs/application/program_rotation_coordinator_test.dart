import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgramRotationCoordinator', () {
    final start = DateTime(2026, 1, 1, 8);

    TrainingProgram program() => TrainingProgram(
          id: 'p1',
          name: 'PPL',
          routineIds: const ['A', 'B', 'C'],
          createdAt: start,
          startedAt: start,
          durationWeeks: 8,
        );

    test('rotates A -> B -> C -> A independently from weekdays', () {
      final history = [
        _session('s1', 'A', start.add(const Duration(days: 1))),
        _session('s2', 'B', start.add(const Duration(days: 4))),
        _session('s3', 'C', start.add(const Duration(days: 9))),
      ];

      final result = ProgramRotationCoordinator.reconcile(program(), history);

      expect(result.completions.map((item) => item.routineId), ['A', 'B', 'C']);
      expect(result.nextRoutineId, 'A');
      expect(result.nextRotationIndex, 0);
    });

    test('free or off-sequence sessions do not advance rotation', () {
      final history = [
        _session('free', null, start.add(const Duration(hours: 4))),
        _session('wrong', 'C', start.add(const Duration(days: 1))),
        _session('a', 'A', start.add(const Duration(days: 2))),
        _session('wrong2', 'C', start.add(const Duration(days: 3))),
        _session('b', 'B', start.add(const Duration(days: 4))),
      ];

      final result = ProgramRotationCoordinator.reconcile(program(), history);

      expect(result.completions.map((item) => item.workoutSessionId), ['a', 'b']);
      expect(result.nextRoutineId, 'C');
    });

    test('reconciliation is idempotent for already recorded sessions', () {
      final history = [
        _session('a', 'A', start.add(const Duration(days: 1))),
      ];
      final first = ProgramRotationCoordinator.reconcile(program(), history);
      final second = ProgramRotationCoordinator.reconcile(first, history);

      expect(second.completions.length, 1);
      expect(second.nextRoutineId, 'B');
    });

    test('missed calendar days never skip the expected rotation slot', () {
      final history = [
        _session('a', 'A', start.add(const Duration(days: 1))),
        _session('b-late', 'B', start.add(const Duration(days: 18))),
      ];
      final result = ProgramRotationCoordinator.reconcile(program(), history);
      expect(result.completions.map((item) => item.routineId), ['A', 'B']);
      expect(result.nextRoutineId, 'C');
    });

    test('duplicate and replay do not double-advance the cycle', () {
      final history = [
        _session('a', 'A', start.add(const Duration(days: 1))),
        _session('a', 'A', start.add(const Duration(days: 1))),
        _session('b', 'B', start.add(const Duration(days: 2))),
      ];
      final result = ProgramRotationCoordinator.reconcile(program(), history);
      expect(result.completions.map((item) => item.workoutSessionId), ['a', 'b']);
      expect(result.nextRoutineId, 'C');
    });

    test('duplicate off-sequence replay never becomes valid later', () {
      final history = [
        _session('dup-c', 'C', start.add(const Duration(hours: 1))),
        _session('a', 'A', start.add(const Duration(hours: 2))),
        _session('b', 'B', start.add(const Duration(hours: 3))),
        _session('dup-c', 'C', start.add(const Duration(hours: 4))),
      ];

      final result = ProgramRotationCoordinator.reconcile(program(), history);

      expect(result.completions.map((item) => item.workoutSessionId), ['a', 'b']);
      expect(result.nextRoutineId, 'C');
    });

    test('sessions before program start cannot mutate rotation', () {
      final history = [
        _session('old-a', 'A', start.subtract(const Duration(days: 1))),
        _session('new-a', 'A', start.add(const Duration(hours: 2))),
      ];
      final result = ProgramRotationCoordinator.reconcile(program(), history);
      expect(result.completions.map((item) => item.workoutSessionId), ['new-a']);
      expect(result.nextRoutineId, 'B');
    });

    test('fixed week counts only the routine assigned to that weekday', () {
      final fixed = program().copyWith(
        scheduleMode: ProgramScheduleMode.fixed,
        targetSessionsPerWeek: 2,
        fixedWeekdayRoutineIds: const {
          DateTime.friday: 'C',
          DateTime.saturday: 'A',
        },
      );
      final friday = DateTime(2026, 1, 2, 8);
      final saturday = DateTime(2026, 1, 3, 8);
      final history = [
        _session('wrong-friday', 'A', friday),
        _session('right-friday', 'C', friday.add(const Duration(hours: 2))),
        _session('right-saturday', 'A', saturday),
      ];

      final result = ProgramRotationCoordinator.reconcile(fixed, history);

      expect(
        result.completions.map((item) => item.workoutSessionId),
        ['right-friday', 'right-saturday'],
      );
      expect(result.nextRotationIndex, fixed.nextRotationIndex);
    });

    test('partial effective workout does not advance rotation', () {
      final partial = _session(
        'partial-a',
        'A',
        start.add(const Duration(days: 1)),
        complete: false,
      );

      final result =
          ProgramRotationCoordinator.reconcile(program(), [partial]);

      expect(result.completions, isEmpty);
      expect(result.nextRoutineId, 'A');
    });

    test('manual deload week remains a program context flag', () {
      final withDeload = program().copyWith(deloadWeeks: const {2});
      expect(withDeload.isDeloadWeekAt(start.add(const Duration(days: 8))), true);
      expect(withDeload.isDeloadWeekAt(start.add(const Duration(days: 1))), false);
    });
  });
}

WorkoutSession _session(
  String id,
  String? routineId,
  DateTime startedAt, {
  bool complete = true,
}) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineId ?? 'Libre',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'exercise-${routineId ?? 'free'}',
        exerciseNameSnapshot: 'Exercise',
        muscleGroupSnapshot: 'Test',
        sets: [
          WorkoutSet(
            weight: 10,
            reps: 10,
            completed: complete,
            setType: WorkoutSetType.working,
          ),
        ],
      ),
    ],
  );
}
