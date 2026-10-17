import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/progress_insight_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);
  final exercises = [
    Exercise(id: 'bench', name: 'Press banca', muscleGroup: 'Pecho'),
    Exercise(id: 'row', name: 'Remo', muscleGroup: 'Espalda'),
    Exercise(id: 'squat', name: 'Sentadilla', muscleGroup: 'Piernas'),
  ];

  WorkoutSession workout(
    String id,
    DateTime date, {
    int chest = 0,
    int back = 0,
    double weight = 50,
    bool warmupOnly = false,
  }) {
    List<WorkoutSet> sets(int n) => [
      if (warmupOnly)
        const WorkoutSet(
          weight: 10, reps: 10, completed: true,
          setType: WorkoutSetType.warmup,
        ),
      for (var i = 0; i < n; i++)
        WorkoutSet(weight: weight, reps: 8, completed: true),
    ];
    return WorkoutSession(
      id: id,
      routineNameSnapshot: 'Prueba',
      startedAt: date.subtract(const Duration(minutes: 35)),
      finishedAt: date,
      durationSeconds: 2100,
      exercises: [
        WorkoutExercise(
          exerciseId: 'bench',
          exerciseNameSnapshot: 'Press banca',
          muscleGroupSnapshot: 'Pecho',
          sets: sets(chest),
        ),
        WorkoutExercise(
          exerciseId: 'row',
          exerciseNameSnapshot: 'Remo',
          muscleGroupSnapshot: 'Espalda',
          sets: sets(back),
        ),
      ],
    );
  }

  List<ProgressInsight> calculate(
    List<WorkoutSession> history, {
    DateTime? from,
    String period = '90D',
  }) => ProgressInsightCalculator.calculate(
    history: history,
    exercises: exercises,
    from: from ?? DateTime(2026, 9, 1),
    now: now,
    periodKey: period,
  );

  test('history with only warmups or incomplete work creates no insights', () {
    expect(calculate([
      workout('only-warmup', DateTime(2026, 10, 7), warmupOnly: true),
      WorkoutSession(
        id: 'incomplete',
        routineNameSnapshot: 'Prueba',
        startedAt: DateTime(2026, 10, 9, 12),
        finishedAt: DateTime(2026, 10, 9, 13),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'bench',
            exerciseNameSnapshot: 'Press banca',
            muscleGroupSnapshot: 'Pecho',
            sets: [WorkoutSet(weight: 80, reps: 3, completed: false)],
          ),
        ],
      ),
    ]), isEmpty);
  });

  test('consistency compares distinct days from two completed weeks', () {
    final history = [
      workout('p1', DateTime(2026, 9, 28, 12), chest: 2, back: 1),
      workout('p2', DateTime(2026, 9, 30, 10), chest: 2, back: 1),
      workout('p3', DateTime(2026, 10, 2, 10), chest: 2, back: 1),
      workout('r1', DateTime(2026, 10, 5, 10), back: 2),
      workout('r2', DateTime(2026, 10, 9, 10), back: 2),
    ];
    final insights = calculate(history);
    final consistency = insights.singleWhere(
        (x) => x.type == ProgressInsightType.consistency);
    expect(consistency.evidence, contains('3 → 2'));
    expect(consistency.periodLabel, contains('28/09/2026'));
    final muscle = insights.singleWhere(
        (x) => x.type == ProgressInsightType.muscle);
    expect(muscle.evidence, contains('6 → 0'));
    expect(muscle.explanation, contains('Pecho'));
    expect(insights.length, 2);
  });

  test('change of filter suppresses incomplete comparisons', () {
    final history = [
      workout('p1', DateTime(2026, 9, 28, 12), chest: 2),
      workout('p2', DateTime(2026, 10, 1, 12), chest: 2),
      workout('r1', DateTime(2026, 10, 5, 12), back: 2),
      workout('r2', DateTime(2026, 10, 9, 12), back: 2),
    ];
    final month = calculate(history);
    expect(month.any((i) => i.type == ProgressInsightType.muscle), true);
    final last7 = calculate(history,
      from: DateTime(2026, 10, 10), period: '7D',
    );
    expect(last7, isEmpty);
  });

  test('three e1RM sessions with enough span produce explainable growth', () {
    final data = [
      workout('old', DateTime(2026, 9, 18, 12), chest: 2, weight: 50),
      workout('mid', DateTime(2026, 9, 28, 12), chest: 2, weight: 55),
      workout('new', DateTime(2026, 10, 11, 12), chest: 2, weight: 60),
    ];
    final insight = calculate(data).singleWhere(
        (item) => item.type == ProgressInsightType.exercise);
    expect(insight.title, contains('Press banca'));
    expect(insight.evidence, contains('20.0 %'));
    expect(insight.explanation, contains('no una medición directa'));
    expect(insight.periodLabel, contains('90D'));
    final reversed = calculate(data.reversed.toList());
    expect(reversed.singleWhere((i) =>
        i.type == ProgressInsightType.exercise).id, insight.id);
  });

  test('three stable sessions do not assert a training plateau', () {
    final stable = [
      workout('a', DateTime(2026, 9, 16, 12), chest: 1),
      workout('b', DateTime(2026, 9, 29, 12), chest: 1),
      workout('c', DateTime(2026, 10, 12, 12), chest: 1),
    ];
    final insight = calculate(stable).singleWhere(
        (item) => item.type == ProgressInsightType.exercise);
    expect(insight.title, contains('estable'));
    expect(insight.explanation, contains('no prueba estancamiento'));
    expect(insight.evidence, contains('0.0 %'));
  });

  test('sparse or contradictory estimates do not create strength claims', () {
    final two = [
      workout('a', DateTime(2026, 9, 12), chest: 1, weight: 45),
      workout('b', DateTime(2026, 10, 11), chest: 1, weight: 75),
    ];
    expect(calculate(two).where((x) =>
        x.type == ProgressInsightType.exercise), isEmpty);
    final conflicting = [
      workout('a', DateTime(2026, 9, 12), chest: 1, weight: 50),
      workout('b', DateTime(2026, 9, 26), chest: 1, weight: 30),
      workout('c', DateTime(2026, 10, 11), chest: 1, weight: 65),
    ];
    expect(calculate(conflicting).where((x) =>
        x.type == ProgressInsightType.exercise), isEmpty);
  });

  test('future samples, activity outside filter and no data are excluded', () {
    final future = [
      workout('future', DateTime(2026, 10, 21), chest: 2),
      workout('past', DateTime(2026, 8, 1), chest: 2),
    ];
    expect(calculate(future), isEmpty);
    expect(calculate([]), isEmpty);
    expect(calculate([workout('only', DateTime(2026, 10, 12),
        chest: 1)]), isEmpty);
  });
}
