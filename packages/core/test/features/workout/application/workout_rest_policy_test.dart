import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_rest_policy.dart';

WorkoutExercise exercise(String id, {String? group, List<WorkoutSet>? sets}) =>
    WorkoutExercise(
      exerciseId: id,
      exerciseNameSnapshot: id,
      muscleGroupSnapshot: 'arms',
      supersetGroupId: group,
      sets:
          sets ??
          [
            for (final entry in [
              (WorkoutSetType.warmup, 15),
              (WorkoutSetType.approach, 30),
              (WorkoutSetType.approach, 30),
              (WorkoutSetType.working, 120),
              (WorkoutSetType.working, 120),
            ])
              WorkoutSet(
                weight: 10,
                reps: 10,
                completed: false,
                setType: entry.$1,
                restSeconds: entry.$2,
              ),
          ],
    );
void main() {
  test(
    'curl/extensions: 30,30,120,120,15 then next exercise and no final rest',
    () {
      final exercises = [exercise('curl'), exercise('extensions')];
      final expected = [30, 30, 120, 120, 15, 30, 30, 120, 120, 0];
      for (var i = 0; i < 10; i++) {
        final ex = i ~/ 5;
        final set = i % 5;
        final sets = [...exercises[ex].sets];
        sets[set] = sets[set].copyWith(completed: true);
        exercises[ex] = exercises[ex].copyWith(sets: sets);
        final result = WorkoutRestPolicy.decide(
          mode: RestTimingMode.nextSet,
          exercises: exercises,
          exerciseIndex: ex,
          setIndex: set,
        );
        expect(result.restSeconds, expected[i], reason: 'slot $i');
        expect(result.shouldStartRest, expected[i] > 0);
      }
    },
  );
  test(
    'legacy mode and old persisted settings retain completed-set timing',
    () {
      expect(
        SettingsState.fromJson({}).restTimingMode,
        RestTimingMode.completedSet,
      );
      expect(
        SettingsState.fromJson({'restTimingMode': 'unknown'}).restTimingMode,
        RestTimingMode.completedSet,
      );
      final settings = const SettingsState().copyWith(
        restTimingMode: RestTimingMode.nextSet,
      );
      expect(
        SettingsState.fromJson(settings.toJson()).restTimingMode,
        RestTimingMode.nextSet,
      );
      final result = WorkoutRestPolicy.decide(
        mode: RestTimingMode.completedSet,
        exercises: [exercise('curl')],
        exerciseIndex: 0,
        setIndex: 2,
      );
      expect(result.restSeconds, 30);
    },
  );
  test('zero-second previous rest does not suppress next working rest', () {
    final ex = exercise(
      'a',
      sets: [
        const WorkoutSet(weight: 1, reps: 10, completed: true, restSeconds: 0),
        const WorkoutSet(
          weight: 1,
          reps: 10,
          completed: false,
          restSeconds: 120,
        ),
      ],
    );
    expect(
      WorkoutRestPolicy.decide(
        mode: RestTimingMode.nextSet,
        exercises: [ex],
        exerciseIndex: 0,
        setIndex: 0,
      ).restSeconds,
      120,
    );
  });
  test('wraps to skipped sets and skips completed or empty exercises', () {
    final exercises = [
      exercise('skipped'),
      exercise('empty', sets: []),
      exercise(
        'last',
        sets: [const WorkoutSet(weight: 1, reps: 10, completed: true)],
      ),
    ];
    expect(
      WorkoutRestPolicy.decide(
        mode: RestTimingMode.nextSet,
        exercises: exercises,
        exerciseIndex: 2,
        setIndex: 0,
      ).restSeconds,
      15,
    );
  });
  test('supersets preserve round rest in next-set mode', () {
    final exercises = [
      exercise(
        'a',
        group: 'pair',
        sets: [
          const WorkoutSet(
            weight: 1,
            reps: 10,
            completed: true,
            restSeconds: 90,
          ),
        ],
      ),
      exercise(
        'b',
        group: 'pair',
        sets: [
          const WorkoutSet(
            weight: 1,
            reps: 10,
            completed: false,
            restSeconds: 120,
          ),
        ],
      ),
    ];
    expect(
      WorkoutRestPolicy.decide(
        mode: RestTimingMode.nextSet,
        exercises: exercises,
        exerciseIndex: 0,
        setIndex: 0,
      ).shouldStartRest,
      false,
    );
    exercises[1] = exercises[1].copyWith(
      sets: [exercises[1].sets[0].copyWith(completed: true)],
    );
    expect(
      WorkoutRestPolicy.decide(
        mode: RestTimingMode.nextSet,
        exercises: exercises,
        exerciseIndex: 1,
        setIndex: 0,
      ).restSeconds,
      120,
    );
  });
}
