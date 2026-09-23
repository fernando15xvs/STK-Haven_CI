import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/superset_coordinator.dart';

WorkoutExercise _exercise({
  required String id,
  String? group,
  required List<WorkoutSet> sets,
}) {
  return WorkoutExercise(
    exerciseId: id,
    exerciseNameSnapshot: id,
    muscleGroupSnapshot: 'test',
    supersetGroupId: group,
    sets: sets,
  );
}

WorkoutSet _working({
  bool completed = false,
  int rest = 90,
}) {
  return WorkoutSet(
    weight: 10,
    reps: 10,
    completed: completed,
    setType: WorkoutSetType.working,
    restSeconds: rest,
  );
}

void main() {
  group('SupersetCoordinator', () {
    test('suppresses rest after first half of a superset round', () {
      final exercises = [
        _exercise(
          id: 'a',
          group: 'g1',
          sets: [_working(completed: true, rest: 90)],
        ),
        _exercise(
          id: 'b',
          group: 'g1',
          sets: [_working(completed: false, rest: 120)],
        ),
      ];

      final decision = SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: 0,
        setIndex: 0,
      );

      expect(decision.shouldStartRest, false);
      expect(decision.restSeconds, 0);
    });

    test('starts rest after second half using the longest configured rest', () {
      final exercises = [
        _exercise(
          id: 'a',
          group: 'g1',
          sets: [_working(completed: true, rest: 90)],
        ),
        _exercise(
          id: 'b',
          group: 'g1',
          sets: [_working(completed: true, rest: 120)],
        ),
      ];

      final decision = SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: 1,
        setIndex: 0,
      );

      expect(decision.shouldStartRest, true);
      expect(decision.restSeconds, 120);
    });

    test('matches working-set ordinal even when warmups differ', () {
      final exercises = [
        _exercise(
          id: 'a',
          group: 'g1',
          sets: [
            const WorkoutSet(
              weight: 0,
              reps: 10,
              completed: true,
              setType: WorkoutSetType.warmup,
              restSeconds: 30,
            ),
            _working(completed: true, rest: 75),
          ],
        ),
        _exercise(
          id: 'b',
          group: 'g1',
          sets: [_working(completed: true, rest: 105)],
        ),
      ];

      final decision = SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: 0,
        setIndex: 1,
      );

      expect(decision.shouldStartRest, true);
      expect(decision.restSeconds, 105);
    });

    test('keeps normal rest behavior outside supersets', () {
      final exercises = [
        _exercise(
          id: 'a',
          sets: [_working(completed: true, rest: 80)],
        ),
      ];

      final decision = SupersetCoordinator.restDecision(
        exercises: exercises,
        exerciseIndex: 0,
        setIndex: 0,
      );

      expect(decision.shouldStartRest, true);
      expect(decision.restSeconds, 80);
    });
  });
}
