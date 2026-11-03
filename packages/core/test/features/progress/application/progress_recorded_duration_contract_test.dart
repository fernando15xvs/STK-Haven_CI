import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutSession session(
    String id, {
    required DateTime startedAt,
    required DateTime finishedAt,
    required int minutes,
    List<WorkoutSet> sets = const [],
  }) =>
      WorkoutSession(
        id: id,
        routineNameSnapshot: 'Rutina de prueba',
        startedAt: startedAt,
        finishedAt: finishedAt,
        durationSeconds: minutes * 60,
        exercises: [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: sets,
          ),
        ],
      );

  final now = DateTime(2026, 11, 3, 15);
  WorkoutSession at(String id, int minutes, {List<WorkoutSet> sets = const []}) =>
      session(
        id,
        startedAt: now.subtract(Duration(minutes: minutes)),
        finishedAt: now,
        minutes: minutes,
        sets: sets,
      );

  test('A: 60-minute recorded session gives an exact 60-minute mean', () {
    final result = summarizeRecordedDurations([at('a', 60)]);
    expect(result.sessionCount, 1);
    expect(result.totalDurationSeconds, 3600);
    expect(result.averageMinutes, 60);
  });

  test('B: partial registered work retains recorded duration, not reward', () {
    final partial = at('b', 45, sets: const [
      WorkoutSet(weight: 30, reps: 10, completed: true),
      WorkoutSet(weight: 30, reps: 10, completed: false),
    ]);
    expect(partial.exercises.single.completed, false);
    expect(partial.exercises.single.sets.where((s) => s.completed), hasLength(1));
    final result = summarizeRecordedDurations([partial]);
    expect(result.sessionCount, 1);
    expect(result.averageMinutes, 45);
    // Rewards/program completion are handled by WorkoutNotifier, not Progreso.
  });

  test('C: a replaced partial snapshot has one recorded session ID', () {
    final replacement = at('same-id', 75, sets: const [
      WorkoutSet(weight: 30, reps: 10, completed: true),
      WorkoutSet(weight: 30, reps: 10, completed: true),
    ]);
    final storedHistory = <WorkoutSession>[replacement];
    expect(storedHistory.map((s) => s.id), ['same-id']);
    expect(summarizeRecordedDurations(storedHistory).averageMinutes, 75);
    // Repository overwrite-by-ID is tested at the persistence boundary.
  });

  test('D: historical empty entry remains counted until DATA-08 decision', () {
    final imported = at('imported', 20);
    final result = summarizeRecordedDurations([imported]);
    expect(result.sessionCount, 1);
    expect(result.averageMinutes, 20);
  });

  test('E: day attribution follows finishedAt after local midnight', () {
    final crossed = session(
      'crossed',
      startedAt: DateTime(2026, 11, 1, 23, 40),
      finishedAt: DateTime(2026, 11, 2, 0, 20),
      minutes: 40,
    );
    expect(
      isSessionInMetricsPeriod(
        crossed,
        startDate: DateTime(2026, 11, 2),
        endDate: DateTime(2026, 11, 3),
      ),
      isTrue,
    );
    final calendar = CalendarHeatmapSnapshot.fromSessions(
      [crossed],
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 3),
    );
    expect(calendar.dayFor(DateTime(2026, 11, 1))!.workoutCount, 0);
    expect(calendar.dayFor(DateTime(2026, 11, 2))!.workoutCount, 1);
  });

  test('F: future completion is not included in current metrics', () {
    final future = session(
      'future',
      startedAt: now,
      finishedAt: now.add(const Duration(minutes: 1)),
      minutes: 1,
    );
    expect(
      isSessionInMetricsPeriod(
        future,
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now,
      ),
      isFalse,
    );
  });

  test('G: 30, 60 and 252 minutes yield 114 without censoring outliers', () {
    final result = summarizeRecordedDurations([
      at('short', 30),
      at('medium', 60),
      at('long', 252),
    ]);
    expect(result.sessionCount, 3);
    expect(result.totalDurationSeconds, (30 + 60 + 252) * 60);
    expect(result.averageMinutes, 114);
  });

  test('H: rolling periods have a stable common upper bound', () {
    final near = at('in', 30);
    final future = session(
      'beyond',
      startedAt: now,
      finishedAt: now.add(const Duration(seconds: 1)),
      minutes: 1,
    );
    for (final filter in TimeFilter.values) {
      final start = filter.startDateAt(now);
      final included = [near, future].where((s) => isSessionInMetricsPeriod(
            s,
            startDate: start,
            endDate: now,
          ));
      expect(included.map((s) => s.id), ['in']);
    }
  });

  test('empty history has a safe zero duration mean', () {
    final summary = summarizeRecordedDurations(const []);
    expect(summary.sessionCount, 0);
    expect(summary.totalDurationSeconds, 0);
    expect(summary.averageMinutes, 0);
  });
}
