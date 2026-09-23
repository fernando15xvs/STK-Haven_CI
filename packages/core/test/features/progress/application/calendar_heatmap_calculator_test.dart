import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutSession session(String id, DateTime finishedAt) {
    return WorkoutSession(
      id: id,
      routineId: 'routine-1',
      routineNameSnapshot: 'Rutina',
      startedAt: finishedAt.subtract(const Duration(minutes: 45)),
      finishedAt: finishedAt,
      durationSeconds: 2700,
      exercises: const [],
    );
  }

  group('CalendarHeatmapSnapshot', () {
    test('aligns the visible grid from Monday through Sunday', () {
      final snapshot = CalendarHeatmapSnapshot.fromSessions(
        [
          session('one', DateTime(2026, 8, 27, 18)),
          session('two', DateTime(2026, 9, 2, 9)),
        ],
        startDate: DateTime(2026, 8, 27),
        endDate: DateTime(2026, 9, 2, 23),
      );

      expect(snapshot.days, hasLength(14));
      expect(snapshot.weekCount, 2);
      expect(snapshot.days.first.date, DateTime(2026, 8, 24));
      expect(snapshot.days.last.date, DateTime(2026, 9, 6));
      expect(snapshot.days.first.isInPeriod, false);
      expect(snapshot.dayFor(DateTime(2026, 8, 27))!.isActive, true);
      expect(snapshot.dayFor(DateTime(2026, 9, 2))!.isActive, true);
    });

    test('groups sessions by date and ignores sessions outside the range', () {
      final snapshot = CalendarHeatmapSnapshot.fromSessions(
        [
          session('before', DateTime(2026, 8, 31, 20)),
          session('morning', DateTime(2026, 9, 1, 8)),
          session('evening', DateTime(2026, 9, 1, 19)),
          session('second-day', DateTime(2026, 9, 2, 12)),
          session('after', DateTime(2026, 9, 8, 8)),
        ],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
      );

      expect(snapshot.activeDays, 2);
      expect(snapshot.totalWorkouts, 3);
      expect(snapshot.dayFor(DateTime(2026, 9, 1))!.workoutCount, 2);
      expect(snapshot.dayFor(DateTime(2026, 9, 2))!.workoutCount, 1);
      expect(snapshot.dayFor(DateTime(2026, 9, 7))!.isActive, false);
    });

    test('returns a safe empty calendar', () {
      final snapshot = CalendarHeatmapSnapshot.fromSessions(
        const [],
        startDate: DateTime(2026, 8, 31),
        endDate: DateTime(2026, 9, 6),
      );

      expect(snapshot.days, hasLength(7));
      expect(snapshot.activeDays, 0);
      expect(snapshot.totalWorkouts, 0);
      expect(snapshot.hasActivity, false);
      expect(snapshot.days.every((day) => !day.isActive), true);
    });

    test('rejects a reversed date range', () {
      expect(
        () => CalendarHeatmapSnapshot.fromSessions(
          const [],
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2026, 9, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
