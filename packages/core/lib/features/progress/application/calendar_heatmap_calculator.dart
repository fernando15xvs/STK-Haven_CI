import 'package:core/domain/models/workout_session.dart';

class CalendarHeatmapDay {
  final DateTime date;
  final int workoutCount;
  final bool isInPeriod;

  const CalendarHeatmapDay({
    required this.date,
    required this.workoutCount,
    required this.isInPeriod,
  });

  bool get isActive => isInPeriod && workoutCount > 0;
}

/// Calendar-ready snapshot of recorded workout days.
///
/// Every active day has the same visual meaning. Multiple sessions on one day
/// are retained for accessible detail, but do not receive a stronger score.
class CalendarHeatmapSnapshot {
  final DateTime startDate;
  final DateTime endDate;
  final List<CalendarHeatmapDay> days;
  final int activeDays;
  final int totalWorkouts;

  const CalendarHeatmapSnapshot({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.activeDays,
    required this.totalWorkouts,
  });

  factory CalendarHeatmapSnapshot.fromSessions(
    Iterable<WorkoutSession> sessions, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Must be on or after startDate.',
      );
    }

    final workoutCounts = <DateTime, int>{};
    for (final session in sessions) {
      final date = _dateOnly(session.finishedAt);
      if (date.isBefore(normalizedStart) || date.isAfter(normalizedEnd)) {
        continue;
      }
      workoutCounts[date] = (workoutCounts[date] ?? 0) + 1;
    }

    final gridStart = normalizedStart.subtract(
      Duration(days: normalizedStart.weekday - DateTime.monday),
    );
    final gridEnd = normalizedEnd.add(
      Duration(days: DateTime.sunday - normalizedEnd.weekday),
    );

    final days = <CalendarHeatmapDay>[];
    for (
      var date = gridStart;
      !date.isAfter(gridEnd);
      date = date.add(const Duration(days: 1))
    ) {
      final isInPeriod =
          !date.isBefore(normalizedStart) && !date.isAfter(normalizedEnd);
      days.add(
        CalendarHeatmapDay(
          date: date,
          workoutCount: isInPeriod ? workoutCounts[date] ?? 0 : 0,
          isInPeriod: isInPeriod,
        ),
      );
    }

    return CalendarHeatmapSnapshot(
      startDate: normalizedStart,
      endDate: normalizedEnd,
      days: List<CalendarHeatmapDay>.unmodifiable(days),
      activeDays: workoutCounts.length,
      totalWorkouts: workoutCounts.values.fold(0, (total, count) => total + count),
    );
  }

  int get weekCount => days.length ~/ 7;

  bool get hasActivity => totalWorkouts > 0;

  CalendarHeatmapDay? dayFor(DateTime value) {
    final target = _dateOnly(value);
    for (final day in days) {
      if (day.date == target) return day;
    }
    return null;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
