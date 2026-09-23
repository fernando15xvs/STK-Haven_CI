import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/routines/application/routine_superset_coordinator.dart';

RoutineExercise exercise(String id, int order, {String? groupId}) {
  return RoutineExercise(
    exerciseId: id,
    order: order,
    targetSets: 3,
    targetRepsMin: 8,
    targetRepsMax: 12,
    restSeconds: 90,
    supersetGroupId: groupId,
  );
}

void main() {
  group('RoutineSupersetCoordinator', () {
    test('pair creates an exact two-exercise group', () {
      final result = RoutineSupersetCoordinator.pair(
        [exercise('a', 0), exercise('b', 1), exercise('c', 2)],
        0,
        2,
        'group-1',
      );

      expect(result[0].supersetGroupId, 'group-1');
      expect(result[1].supersetGroupId, isNull);
      expect(result[2].supersetGroupId, 'group-1');
      expect(RoutineSupersetCoordinator.groups(result)['group-1'], [0, 2]);
    });

    test('pair releases previous partners before creating a new pair', () {
      final result = RoutineSupersetCoordinator.pair(
        [
          exercise('a', 0, groupId: 'old-a'),
          exercise('b', 1, groupId: 'old-a'),
          exercise('c', 2, groupId: 'old-c'),
          exercise('d', 3, groupId: 'old-c'),
        ],
        1,
        2,
        'new-group',
      );

      expect(result[0].supersetGroupId, isNull);
      expect(result[1].supersetGroupId, 'new-group');
      expect(result[2].supersetGroupId, 'new-group');
      expect(result[3].supersetGroupId, isNull);
    });

    test('unpair clears both exercises in the group', () {
      final result = RoutineSupersetCoordinator.unpair(
        [
          exercise('a', 0, groupId: 'group-1'),
          exercise('b', 1, groupId: 'group-1'),
          exercise('c', 2),
        ],
        0,
      );

      expect(result[0].supersetGroupId, isNull);
      expect(result[1].supersetGroupId, isNull);
      expect(result[2].supersetGroupId, isNull);
    });

    test('normalize removes orphaned and oversized groups', () {
      final result = RoutineSupersetCoordinator.normalize([
        exercise('a', 0, groupId: 'orphan'),
        exercise('b', 1, groupId: 'valid'),
        exercise('c', 2, groupId: 'valid'),
        exercise('d', 3, groupId: 'too-many'),
        exercise('e', 4, groupId: 'too-many'),
        exercise('f', 5, groupId: 'too-many'),
      ]);

      expect(result[0].supersetGroupId, isNull);
      expect(result[1].supersetGroupId, 'valid');
      expect(result[2].supersetGroupId, 'valid');
      expect(result[3].supersetGroupId, isNull);
      expect(result[4].supersetGroupId, isNull);
      expect(result[5].supersetGroupId, isNull);
    });
  });
}
