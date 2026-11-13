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

  test('overnight completed session is attributed to finish day', () {
    final overnight = session(at: DateTime(2026, 10, 13, 23, 30), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([overnight], today),
        same(overnight));
  });

  test('a session started today but finished tomorrow is not finalized today', () {
    final tomorrow = session(at: DateTime(2026, 10, 14, 23, 30), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([tomorrow], today), isNull);
  });

  test('future-dated completion today is not yet a finished workout', () {
    final later = session(at: DateTime(2026, 10, 14, 16, 30), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([later], today), isNull);
  });

  test('returns latest completed by finish time, not start time', () {
    final morning = session(at: DateTime(2026, 10, 14, 9), completed: true);
    final afternoon = session(at: DateTime(2026, 10, 14, 14), completed: true);
    expect(TodaysWorkoutStatus.latestCompletedToday([morning, afternoon], today),
        same(afternoon));
  });
}
