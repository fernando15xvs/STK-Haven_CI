import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roadmap 2.0 synthetic history scale', () {
    test('1k sessions build indexed exercise/routine lookups consistently', () {
      final history = _history(1000);
      final watch = Stopwatch()..start();
      final index = WorkoutHistoryIndex.build(history);
      watch.stop();

      expect(index.sessionsNewestFirst.length, 1000);
      expect(index.exerciseOccurrences('shared_press').length, 1000);
      expect(index.routineSessions('routine_0').length, 250);
      expect(
        index.latestCompletedWorkingOccurrence('shared_press')?.session.id,
        'session_999',
      );
      // Recorded for the final audit; no brittle wall-clock pass/fail threshold.
      // ignore: avoid_print
      print('INDEX_1K_MS=${watch.elapsedMilliseconds}');
    });

    test('5k sessions keep global analytics correct with chart downsampling', () {
      final history = _history(5000);
      final indexWatch = Stopwatch()..start();
      final index = WorkoutHistoryIndex.build(history);
      indexWatch.stop();

      final progressWatch = Stopwatch()..start();
      final trend = ExerciseProgressCalculator.calculateTrend(
        index.sessionsNewestFirst,
        'shared_press',
        maxChartPoints: 120,
      );
      progressWatch.stop();

      expect(index.exerciseOccurrences('shared_press').length, 5000);
      expect(trend.sessionCount, 5000);
      expect(trend.completedWorkSets, 5000);
      expect(trend.history1RM.length, lessThanOrEqualTo(120));
      expect(trend.historyWeight.length, lessThanOrEqualTo(120));
      expect(trend.latestSession?.sessionId, 'session_4999');
      // ignore: avoid_print
      print('INDEX_5K_MS=${indexWatch.elapsedMilliseconds}');
      // ignore: avoid_print
      print('PROGRESS_5K_MS=${progressWatch.elapsedMilliseconds}');
    });
  });
}

List<WorkoutSession> _history(int count) {
  final base = DateTime(2020, 1, 1);
  return List.generate(count, (index) {
    final date = base.add(Duration(hours: index * 6));
    return WorkoutSession(
      id: 'session_$index',
      routineId: 'routine_${index % 4}',
      routineNameSnapshot: 'Routine ${index % 4}',
      startedAt: date,
      finishedAt: date.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      exercises: [
        WorkoutExercise(
          exerciseId: 'shared_press',
          exerciseNameSnapshot: 'Press',
          muscleGroupSnapshot: 'Pecho',
          sets: [
            WorkoutSet(
              weight: 40 + (index % 40).toDouble(),
              reps: 6 + (index % 7),
              rir: index % 4,
              completed: true,
            ),
          ],
        ),
      ],
    );
  }, growable: false);
}
