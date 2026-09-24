import 'package:core/domain/models/habit_study_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HabitStudyTimerState', () {
    final start = DateTime(2026, 9, 24, 10);

    test('uses timestamps so background time is included', () {
      final timer = HabitStudyTimerState(
        taskId: 'read',
        targetSeconds: 600,
        runningSince: start,
        updatedAt: start,
      );

      expect(
        timer.elapsedSecondsAt(start.add(const Duration(minutes: 3))),
        180,
      );
      expect(
        timer.remainingSecondsAt(start.add(const Duration(minutes: 3))),
        420,
      );
    });

    test('pause freezes accumulated elapsed time', () {
      final timer = HabitStudyTimerState(
        taskId: 'read',
        targetSeconds: 600,
        runningSince: start,
        updatedAt: start,
      );

      final paused = timer.pause(start.add(const Duration(minutes: 4)));

      expect(paused.isRunning, isFalse);
      expect(
        paused.elapsedSecondsAt(start.add(const Duration(hours: 2))),
        240,
      );
    });

    test('resume continues from accumulated time', () {
      final paused = HabitStudyTimerState(
        taskId: 'read',
        targetSeconds: 600,
        accumulatedSeconds: 240,
        updatedAt: start,
      );

      final resumed = paused.resume(start.add(const Duration(minutes: 10)));

      expect(
        resumed.elapsedSecondsAt(start.add(const Duration(minutes: 12))),
        360,
      );
    });

    test('round-trips an active timer', () {
      final timer = HabitStudyTimerState(
        taskId: 'study',
        targetSeconds: 900,
        accumulatedSeconds: 120,
        runningSince: start,
        updatedAt: start,
      );

      final restored = HabitStudyTimerState.fromJson(timer.toJson());

      expect(restored.taskId, 'study');
      expect(restored.targetSeconds, 900);
      expect(restored.accumulatedSeconds, 120);
      expect(restored.runningSince, start);
    });
  });
}
