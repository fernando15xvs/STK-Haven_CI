import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 17);

  WorkoutSession recorded(
    String id, {
    DateTime? finishedAt,
    List<WorkoutSet> sets = const [],
  }) {
    final finish = finishedAt ?? now.subtract(const Duration(hours: 1));
    return WorkoutSession(
      id: id,
      routineNameSnapshot: 'Rutina importada',
      startedAt: finish.subtract(const Duration(minutes: 45)),
      finishedAt: finish,
      durationSeconds: 2700,
      exercises: [
        WorkoutExercise(
          exerciseId: 'press',
          exerciseNameSnapshot: 'Press',
          muscleGroupSnapshot: 'Pecho',
          sets: sets,
        ),
      ],
    );
  }

  const working = WorkoutSet(weight: 30, reps: 10, completed: true);
  const pending = WorkoutSet(weight: 30, reps: 10, completed: false);
  const warmup = WorkoutSet(
    weight: 10,
    reps: 12,
    completed: true,
    setType: WorkoutSetType.warmup,
  );

  test('an imported empty row is retained in history but not activity', () {
    final imported = recorded('imported');
    expect(hasRecordedTrainingActivity(imported), isFalse);
    final history = [imported];
    expect(history.single.id, 'imported');
    expect(history.where(hasRecordedTrainingActivity), isEmpty);
  });

  test('warmup-only and pending-only entries are not training frequency', () {
    expect(hasRecordedTrainingActivity(recorded('warmup', sets: [warmup])),
        isFalse);
    expect(hasRecordedTrainingActivity(recorded('pending', sets: [pending])),
        isFalse);
    expect(
      hasRecordedTrainingActivity(recorded('no-reps', sets: const [
        WorkoutSet(weight: 30, reps: 0, completed: true),
      ])),
      isFalse,
    );
  });

  test('partially finalized session counts only with actual completed work', () {
    final partial = recorded('partial', sets: [working, pending]);
    expect(partial.exercises.single.completed, isFalse);
    expect(hasRecordedTrainingActivity(partial), isTrue);
    // Completion rewards and program progress remain separately protected
    // by WorkoutNotifier. This predicate is read-only.
  });

  test('bodyweight set with positive reps counts even at zero kilograms', () {
    final bodyweight = recorded('body', sets: const [
      WorkoutSet(weight: 0, reps: 12, completed: true),
    ]);
    expect(hasRecordedTrainingActivity(bodyweight), isTrue);
  });

  test('effective training and heatmap agree on midnight and empty imports', () {
    final previousDay = recorded(
      'cross-midnight',
      finishedAt: DateTime(2026, 11, 2, 0, 20),
      sets: [working],
    );
    final emptySameDay = recorded(
      'empty-import',
      finishedAt: DateTime(2026, 11, 2, 8),
    );
    final today = recorded('today', sets: [working, pending]);
    final effective = [previousDay, emptySameDay, today]
        .where(hasRecordedTrainingActivity)
        .toList();
    expect(effective.map((s) => s.id), ['cross-midnight', 'today']);
    final calendar = CalendarHeatmapSnapshot.fromSessions(
      effective,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 3),
    );
    expect(calendar.activeDays, 2);
    expect(calendar.totalWorkouts, 2);
    expect(calendar.dayFor(DateTime(2026, 11, 2))!.workoutCount, 1);
    expect(calendar.dayFor(DateTime(2026, 11, 3))!.workoutCount, 1);
  });

  test('future record later today stays out of calendar activity', () {
    final valid = recorded('valid', sets: [working]);
    final future = recorded(
      'later-today',
      finishedAt: now.add(const Duration(hours: 2)),
      sets: [working],
    );
    final eligible = [valid, future]
        .where((s) => isRecordedTrainingActivityAsOf(s, now))
        .toList();
    expect(eligible.map((s) => s.id), ['valid']);
    final snapshot = CalendarHeatmapSnapshot.fromSessions(
      eligible,
      startDate: DateTime(2026, 11, 2),
      endDate: DateTime(2026, 11, 3),
    );
    expect(snapshot.totalWorkouts, 1);
    expect(snapshot.activeDays, 1);
  });

  test('current/previous windows share eligibility without future entries', () {
    final start = TimeFilter.week.startDateAt(now);
    final prevStart = start.subtract(const Duration(days: 7));
    final sessions = [
      recorded('current', sets: [working]),
      recorded('prior',
          finishedAt: start.subtract(const Duration(days: 2)),
          sets: [working]),
      recorded('empty', sets: const []),
      recorded('future',
          finishedAt: now.add(const Duration(seconds: 1)),
          sets: [working]),
    ].where((s) => isRecordedTrainingActivityAsOf(s, now)).toList();
    final current = sessions
        .where((s) =>
            isSessionInMetricsPeriod(s, startDate: start, endDate: now))
        .map((s) => s.id);
    final prior = sessions
        .where((s) =>
            s.finishedAt.isAfter(prevStart) &&
            s.finishedAt.isBefore(start))
        .map((s) => s.id);
    expect(current, ['current']);
    expect(prior, ['prior']);
  });
}
