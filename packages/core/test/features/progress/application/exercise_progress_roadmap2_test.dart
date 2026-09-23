import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseProgressCalculator Roadmap 2.0', () {
    test('compares latest session with previous across different routines', () {
      final history = [
        _session('s1', 'Push A', DateTime(2026, 1, 1), 50, 8, 2),
        _session('s2', 'Push B', DateTime(2026, 1, 5), 52, 9, 1),
      ];

      final trend = ExerciseProgressCalculator.calculateTrend(history, 'press');
      final comparison = trend.latestComparison!;

      expect(trend.sessionCount, 2);
      expect(comparison.latest.routineName, 'Push B');
      expect(comparison.previous.routineName, 'Push A');
      expect(comparison.weightDelta, 2);
      expect(comparison.repsDelta, 1);
      expect(comparison.rirDelta, -1);
      expect(comparison.volumeDelta, greaterThan(0));
    });

    test('plateau is informational after three tightly clustered e1RM sessions', () {
      final history = [
        _session('a', 'A', DateTime(2026, 2, 1), 50, 10, 2),
        _session('b', 'B', DateTime(2026, 2, 5), 50, 10, 2),
        _session('c', 'C', DateTime(2026, 2, 9), 50, 10, 2),
      ];

      final trend = ExerciseProgressCalculator.calculateTrend(history, 'press');
      expect(trend.hasPlateauSignal, true);
    });

    test('unilateral latest session exposes neutral side difference', () {
      final date = DateTime(2026, 3, 1);
      final session = WorkoutSession(
        id: 'u1',
        routineId: 'legs',
        routineNameSnapshot: 'Pierna',
        startedAt: date,
        finishedAt: date.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'split',
            exerciseNameSnapshot: 'Split squat',
            muscleGroupSnapshot: 'Piernas',
            unilateral: true,
            sets: [
              WorkoutSet(
                weight: 20,
                reps: 10,
                completed: true,
                leftCompleted: true,
                rightCompleted: true,
                leftWeight: 20,
                leftReps: 10,
                rightWeight: 18,
                rightReps: 10,
              ),
            ],
          ),
        ],
      );

      final trend = ExerciseProgressCalculator.calculateTrend([session], 'split');
      expect(trend.latestSession!.hasUnilateralDetail, true);
      expect(trend.latestSideDifferencePercent, isNotNull);
      expect(trend.latestSideDifferencePercent!, greaterThan(0));
      expect(trend.totalVolume, 190);
    });

    test('chart point collections are downsampled without changing session count', () {
      final history = List.generate(
        300,
        (index) => _session(
          's$index',
          'R${index % 3}',
          DateTime(2025, 1, 1).add(Duration(days: index)),
          40 + (index % 20).toDouble(),
          8 + (index % 4),
          2,
        ),
      );

      final trend = ExerciseProgressCalculator.calculateTrend(
        history,
        'press',
        maxChartPoints: 60,
      );

      expect(trend.sessionCount, 300);
      expect(trend.history1RM.length, lessThanOrEqualTo(60));
      expect(trend.historyWeight.length, lessThanOrEqualTo(60));
      expect(trend.historyReps.length, lessThanOrEqualTo(60));
    });
  });
}

WorkoutSession _session(
  String id,
  String routineName,
  DateTime date,
  double weight,
  int reps,
  int rir,
) {
  return WorkoutSession(
    id: id,
    routineId: routineName,
    routineNameSnapshot: routineName,
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'press',
        exerciseNameSnapshot: 'Press',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          WorkoutSet(
            weight: weight,
            reps: reps,
            rir: rir,
            completed: true,
          ),
        ],
      ),
    ],
  );
}
