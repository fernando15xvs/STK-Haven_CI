import 'package:core/domain/models/habit_task.dart';

class HabitScheduleService {
  const HabitScheduleService._();

  static bool isDueOn(HabitTask task, DateTime instant) {
    if (task.archived) return false;

    final date = _dateOnly(instant);
    final createdDate = _dateOnly(task.createdAt);
    if (date.isBefore(createdDate)) return false;

    final scheduled = task.scheduledAt;
    final scheduledDate = scheduled == null ? null : _dateOnly(scheduled);

    switch (task.recurrence) {
      case HabitRecurrenceType.once:
        final dueDate = scheduledDate ?? createdDate;
        return _sameDate(date, dueDate);
      case HabitRecurrenceType.daily:
        if (scheduledDate != null && date.isBefore(scheduledDate)) {
          return false;
        }
        return true;
      case HabitRecurrenceType.weekly:
        if (scheduledDate != null && date.isBefore(scheduledDate)) {
          return false;
        }
        if (task.weekdays.isEmpty) {
          final fallback = scheduledDate?.weekday ?? createdDate.weekday;
          return date.weekday == fallback;
        }
        return task.weekdays.contains(date.weekday);
    }
  }

  static bool isCompletedOn(
    HabitTask task,
    Iterable<HabitTaskCompletion> completions,
    DateTime instant,
  ) {
    final date = _dateOnly(instant);
    return completions.any(
      (completion) =>
          completion.taskId == task.id &&
          _sameDate(_dateOnly(completion.completedAt), date),
    );
  }

  static List<DateTime> dueDates({
    required HabitTask task,
    required DateTime from,
    required int days,
  }) {
    if (days <= 0) return const <DateTime>[];

    final result = <DateTime>[];
    var cursor = _dateOnly(from);
    for (var i = 0; i < days; i++) {
      if (isDueOn(task, cursor)) result.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  static int currentStreak({
    required HabitTask task,
    required Iterable<HabitTaskCompletion> completions,
    required DateTime today,
  }) {
    if (task.recurrence == HabitRecurrenceType.once) {
      return isCompletedOn(task, completions, today) ? 1 : 0;
    }

    var streak = 0;
    var cursor = _dateOnly(today);

    if (isDueOn(task, cursor) &&
        !isCompletedOn(task, completions, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    for (var guard = 0; guard < 3660; guard++) {
      if (!isDueOn(task, cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }

      if (!isCompletedOn(task, completions, cursor)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
