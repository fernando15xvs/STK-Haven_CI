import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_date_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutSession sample(String id, DateTime start, DateTime finish) =>
      WorkoutSession(
        id: id, routineNameSnapshot: 'Upper',
        startedAt: start, finishedAt: finish,
        exercises: const [], durationSeconds: finish.difference(start).inSeconds,
      );

  test('midnight-crossing workout shows local completion date', () {
    final start = DateTime(2026, 11, 12, 23, 59);
    final end = DateTime(2026, 11, 13, 0, 1);
    final completed = sample('night', start, end);
    expect(WorkoutHistoryDatePolicy.localCompletionTime(completed).day, 13);
    expect(completed.startedAt.day, 12);
  });

  test('finish-time ordering and explicit local timezone conversion', () {
    final old = sample('old', DateTime.utc(2026, 11, 13, 5),
        DateTime.utc(2026, 11, 13, 6));
    final recent = sample('recent', DateTime.utc(2026, 11, 13, 6),
        DateTime.utc(2026, 11, 13, 7));
    final items = [old, recent]..sort(WorkoutHistoryDatePolicy.latestFirst);
    expect(items.map((s) => s.id).toList(), ['recent', 'old']);
    expect(WorkoutHistoryDatePolicy.localCompletionTime(old),
        old.finishedAt.toLocal());
  });
}
