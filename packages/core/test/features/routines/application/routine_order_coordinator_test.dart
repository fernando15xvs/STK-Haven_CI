import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/routines/application/routine_order_coordinator.dart';

void main() {
  RoutineExercise exercise(
    String id,
    int order, {
    String? supersetGroupId,
    int warmupSets = 0,
    int approachSets = 0,
    bool unilateral = false,
  }) {
    return RoutineExercise(
      exerciseId: id,
      order: order,
      targetSets: 3,
      targetRepsMin: 8,
      targetRepsMax: 12,
      restSeconds: 90,
      warmupSets: warmupSets,
      approachSets: approachSets,
      unilateral: unilateral,
      supersetGroupId: supersetGroupId,
    );
  }

  group('RoutineOrderCoordinator', () {
    test('move reorders exercises and rewrites sequential order values', () {
      final input = [
        exercise('bench', 0),
        exercise('row', 1),
        exercise('curl', 2),
      ];

      final result = RoutineOrderCoordinator.move(input, 2, 0);

      expect(result.map((item) => item.exerciseId), ['curl', 'bench', 'row']);
      expect(result.map((item) => item.order), [0, 1, 2]);
    });

    test('move preserves full exercise configuration and superset membership', () {
      final input = [
        exercise(
          'bench',
          0,
          supersetGroupId: 'pair-1',
          warmupSets: 2,
          approachSets: 1,
        ),
        exercise(
          'row',
          1,
          supersetGroupId: 'pair-1',
          unilateral: true,
        ),
        exercise('curl', 2),
      ];

      final result = RoutineOrderCoordinator.move(input, 0, 2);
      final bench = result.singleWhere((item) => item.exerciseId == 'bench');
      final row = result.singleWhere((item) => item.exerciseId == 'row');

      expect(bench.supersetGroupId, 'pair-1');
      expect(bench.warmupSets, 2);
      expect(bench.approachSets, 1);
      expect(row.supersetGroupId, 'pair-1');
      expect(row.unilateral, true);
    });

    test('normalize repairs stale order values without changing list order', () {
      final input = [
        exercise('bench', 9),
        exercise('row', 3),
      ];

      final result = RoutineOrderCoordinator.normalize(input);

      expect(result.map((item) => item.exerciseId), ['bench', 'row']);
      expect(result.map((item) => item.order), [0, 1]);
    });
  });
}
