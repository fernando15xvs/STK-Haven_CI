import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = RoutineExercise(
    exerciseId: 'pulley',
    order: 0,
    targetSets: 2,
    targetRepsMin: 8,
    targetRepsMax: 10,
    restSeconds: 90,
  );

  WorkoutSession performed(String id, int day, {int reps = 12}) =>
      WorkoutSession(
        id: id,
        routineId: 'a',
        routineNameSnapshot: 'Rutina A',
        startedAt: DateTime(2026, 1, day),
        finishedAt: DateTime(2026, 1, day, 1),
        durationSeconds: 3600,
        exercises: [
          WorkoutExercise(
            exerciseId: 'pulley',
            exerciseNameSnapshot: 'Polea',
            muscleGroupSnapshot: 'Espalda',
            sets: [
              for (var i = 0; i < 2; i++)
                WorkoutSet(weight: 120, reps: reps, rir: 3, completed: true),
            ],
          ),
        ],
      );

  ProgressionSuggestion analyze(WorkoutSession current,
      {Iterable<WorkoutSession> recent = const [],
       Map<String, double> steps = const {}}) =>
      ProgressionEngine.analyze(
        session: current,
        routineTargets: const [target],
        isRirEnabled: true,
        defaultIncrementKg: 2.5,
        exerciseIncrementsKg: steps,
        recentSessions: recent,
      ).single;

  test('12 reps with an 8–10 target surfaces a contextual prompt', () {
    final suggestion = analyze(performed('current', 2));
    expect(suggestion.reason, ProgressionReason.exceededRepRange);
    expect(suggestion.type, ProgressionType.maintain);
  });

  test('per-exercise machine jump is respected after confirmation', () {
    final current = performed('current', 2);
    final previous = performed('previous', 1);
    final s = analyze(current, recent: [previous],
        steps: const {'pulley': 5});
    expect(s.type, ProgressionType.increase);
    expect(s.suggestedWeightKg, 125);
  });

  test('unsafe next stack jump is never fractionalized', () {
    final s = ProgressionEngine.analyze(
      session: performed('current', 2),
      routineTargets: const [target],
      isRirEnabled: false,
      defaultIncrementKg: 2.5,
      exerciseIncrementsKg: const {'pulley': 10},
      recentSessions: [performed('previous', 1)],
    ).single;
    expect(s.reason, ProgressionReason.incrementExceedsSafeStep);
    expect(s.suggestedWeightKg, 120);
  });

  test('canonical kg increments survive kg to lb and back', () {
    const initial = SettingsState(
      defaultIncrement: 2.5,
      exerciseIncrementsKg: {'pulley': 5},
    );
    final saved = SettingsState.fromJson(initial.toJson());
    expect(saved.incrementForExercise('pulley'), 5);
    expect(saved.incrementForExercise('other'), 2.5);

    final lb = saved.copyWith(weightUnit: WeightUnit.lb);
    final displayed = WeightConverter.displayWeight(
      lb.incrementForExercise('pulley'), lb.weightUnit);
    expect(displayed, closeTo(11.0231, 0.001));

    final roundTrip = WeightConverter.toCanonicalKg(displayed, lb.weightUnit);
    expect(roundTrip, closeTo(5, 1e-8));
    final kg = lb.copyWith(weightUnit: WeightUnit.kg);
    expect(kg.incrementForExercise('pulley'), 5);
    expect(kg.defaultIncrement, 2.5);
  });

  test('five pounds is neither stored nor suggested as five kilograms', () {
    final kg = WeightConverter.toCanonicalKg(5, WeightUnit.lb);
    expect(kg, closeTo(2.26796, 0.0001));
    expect(WeightConverter.displayWeight(kg, WeightUnit.lb), closeTo(5, 1e-6));
  });

  test('old and malformed settings fall back without losing unit', () {
    final old = SettingsState.fromJson(
        {'weightUnit': 'lb', 'defaultIncrement': 2.5});
    expect(old.exerciseIncrementsKg, isEmpty);
    expect(old.weightUnit, WeightUnit.lb);
    final malformed = SettingsState.fromJson({
      'exerciseIncrementsKg': {'a': -3, 'b': '10', 'c': 5.0},
    });
    expect(malformed.exerciseIncrementsKg, {'c': 5});
  });
}
