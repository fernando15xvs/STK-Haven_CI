import 'package:core/domain/models/routine.dart';
import 'package:core/features/routines/application/routine_schedule_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Routine routine(List<int> scheduledDays) {
    return Routine(
      id: 'upper-a',
      name: 'Upper A',
      scheduledDays: scheduledDays,
      exercises: const [
        RoutineExercise(
          exerciseId: 'bench',
          order: 0,
          targetSets: 3,
          targetRepsMin: 8,
          targetRepsMax: 12,
          restSeconds: 90,
          warmupSets: 2,
          approachSets: 1,
          unilateral: true,
          supersetGroupId: 'pair-1',
        ),
      ],
      createdAt: DateTime(2026),
      notes: 'Priorizar técnica',
    );
  }

  group('RoutineScheduleCoordinator', () {
    test('moves only the selected occurrence and preserves routine data', () {
      final input = routine([1, 3, 5]);

      final result = RoutineScheduleCoordinator.moveToDay(
        routine: input,
        fromDay: 1,
        toDay: 2,
      );

      expect(result.scheduledDays, [2, 3, 5]);
      expect(result.id, input.id);
      expect(result.name, input.name);
      expect(result.notes, input.notes);
      expect(result.exercises, same(input.exercises));
      expect(result.exercises.single.supersetGroupId, 'pair-1');
    });

    test('keeps days unique and sorted when destination already exists', () {
      final input = routine([1, 2, 5]);

      final result = RoutineScheduleCoordinator.moveToDay(
        routine: input,
        fromDay: 1,
        toDay: 2,
      );

      expect(result.scheduledDays, [2, 5]);
    });

    test('returns the same routine when there is nothing to move', () {
      final input = routine([1, 3]);

      final sameDay = RoutineScheduleCoordinator.moveToDay(
        routine: input,
        fromDay: 1,
        toDay: 1,
      );
      final missingDay = RoutineScheduleCoordinator.moveToDay(
        routine: input,
        fromDay: 2,
        toDay: 4,
      );

      expect(sameDay, same(input));
      expect(missingDay, same(input));
    });

    test('rejects weekday values outside the supported range', () {
      final input = routine([1, 3]);

      expect(
        () => RoutineScheduleCoordinator.moveToDay(
          routine: input,
          fromDay: 0,
          toDay: 2,
        ),
        throwsRangeError,
      );
      expect(
        () => RoutineScheduleCoordinator.moveToDay(
          routine: input,
          fromDay: 1,
          toDay: 8,
        ),
        throwsRangeError,
      );
    });
  });
}
