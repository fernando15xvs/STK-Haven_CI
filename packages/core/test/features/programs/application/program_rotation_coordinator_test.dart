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

    test('manual deload week remains a program context flag', () {
      final withDeload = program().copyWith(deloadWeeks: const {2});
      expect(withDeload.isDeloadWeekAt(start.add(const Duration(days: 8))), true);
      expect(withDeload.isDeloadWeekAt(start.add(const Duration(days: 1))), false);
    });
  });
}

WorkoutSession _session(String id, String? routineId, DateTime startedAt) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineId ?? 'Libre',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: const [],
  );
}
