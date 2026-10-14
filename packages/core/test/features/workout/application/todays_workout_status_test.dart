import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session({
  required DateTime at,
  required bool completed,
}) => WorkoutSession(
  id: at.toIso8601String(),
  routineNameSnapshot: 'Upper A',
  startedAt: at,
  finishedAt: at.add(const Duration(hours: 1)),
  durationSeconds: 3600,
  exercises: [
    WorkoutExercise(
      exerciseId: 'press',
      exerciseNameSnapshot: 'Press',
      muscleGroupSnapshot: 'Pecho',
      sets: [
        WorkoutSet(
          weight: 30,
          reps: 8,
          completed: completed,
        ),
      ],
    ),
  ],
);

void main() {
  final today = DateTime(2026, 10, 14, 17);
  test('completed today is shown as finalizado', () {
    final done = session(at: DateTime(2026, 10, 14, 10), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([done], today), same(done));
  });
  test('partial workout is not marked complete', () {
    final partial = session(at: DateTime(2026, 10, 14, 10), completed: false);
    expect(TodaysWorkoutStatus.latestCompletedToday([partial], today), isNull);
  });
  test('past workout can be trained again another day', () {
    final yesterday = session(at: DateTime(2026, 10, 13, 10), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([yesterday], today), isNull);
  });
}
