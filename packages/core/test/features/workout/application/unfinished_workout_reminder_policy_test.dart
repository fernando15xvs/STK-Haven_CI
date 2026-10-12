import 'package:core/features/workout/application/unfinished_workout_reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final started = DateTime(2026, 10, 10, 10);
  test('three hour threshold is inclusive', () {
    expect(UnfinishedWorkoutReminderPolicy.isStale(
        started, started.add(const Duration(hours: 2))), isFalse);
    expect(UnfinishedWorkoutReminderPolicy.isStale(
        started, started.add(const Duration(hours: 3))), isTrue);
  });
  test('nudge and follow-up are based on last activity', () {
    expect(UnfinishedWorkoutReminderPolicy.upcoming(
      lastActivityAt: started, now: started.add(const Duration(hours: 1)),
    ), [
      started.add(const Duration(hours: 3)),
      started.add(const Duration(hours: 24)),
    ]);
  });
  test('past reminders are never fired retroactively', () {
    expect(UnfinishedWorkoutReminderPolicy.upcoming(
      lastActivityAt: started, now: started.add(const Duration(days: 3)),
    ), isEmpty);
  });
}
