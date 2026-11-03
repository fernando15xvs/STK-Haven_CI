import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 2, 22);
  final from = now.subtract(const Duration(days: 30));

  WorkoutSession recordedSession(
    DateTime finishedAt, {
    bool pendingWorkingSet = false,
  }) =>
      WorkoutSession(
        id: 'test-${finishedAt.microsecondsSinceEpoch}',
        routineId: 'routine',
        routineNameSnapshot: 'Rutina',
        startedAt: finishedAt.subtract(const Duration(minutes: 45)),
        finishedAt: finishedAt,
        durationSeconds: 2700,
        exercises: [
          WorkoutExercise(
            exerciseId: 'bench',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              const WorkoutSet(weight: 30, reps: 8, completed: true),
              if (pendingWorkingSet)
                const WorkoutSet(weight: 30, reps: 8, completed: false),
            ],
          ),
        ],
      );

  bool inPeriod(WorkoutSession session) => isSessionInMetricsPeriod(
        session,
        startDate: from,
        endDate: now,
      );

  test('a future-dated completion must not inflate current metrics', () {
    expect(inPeriod(recordedSession(now.add(const Duration(days: 1)))),
        isFalse);
    expect(inPeriod(recordedSession(now.add(const Duration(seconds: 1)))),
        isFalse);
  });

  test('the actual period includes now and excludes the preceding period',
      () {
    expect(inPeriod(recordedSession(now)), isTrue);
    expect(inPeriod(recordedSession(now.subtract(const Duration(days: 7)))),
        isTrue);
    expect(inPeriod(recordedSession(from)), isFalse);
    expect(
      inPeriod(recordedSession(from.subtract(const Duration(seconds: 1)))),
      isFalse,
    );
  });

  test('partially finalized session with completed work is not dropped',
      () {
    final partial = recordedSession(
      now.subtract(const Duration(hours: 2)),
      pendingWorkingSet: true,
    );
    expect(partial.exercises.single.sets.first.completed, isTrue);
    expect(partial.exercises.single.sets.last.completed, isFalse);
    expect(inPeriod(partial), isTrue);
    // This date filter does not grant rewards nor advance a training plan.
  });
}
