import 'package:core/domain/models/habit_task.dart';

class HabitScheduleService {
  const HabitScheduleService._();

  static bool isDueOn(HabitTask task, DateTime instant) {
    if (task.archived) return false;

    final date = _dateOnly(instant);
    final createdDate = _dateOnly(task.createdAt);
    if(task.pauseHistory.any((p)=>!date.isBefore(_dateOnly(p.from))&&date.isBefore(_dateOnly(p.until))))return false;
    if (task.pausedUntil != null && date.isBefore(_dateOnly(task.pausedUntil!)) &&
        (task.pausedFrom==null || !date.isBefore(_dateOnly(task.pausedFrom!)))) return false;
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
        if (task.weeklyGoal != null) return true;
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
    if(task.targetQuantity!=null&&task.targetQuantity!>0){
      return quantityOn(task,completions,instant)>=task.targetQuantity!;
    }
    return completions.any(
      (completion) =>
          completion.taskId == task.id &&
          completion.status == HabitTaskCompletionStatus.completed &&
          _sameDate(_dateOnly(completion.completedAt), date),
    );
  }

  static double quantityOn(HabitTask task,Iterable<HabitTaskCompletion> rows,DateTime instant)=>
    rows.where((c)=>c.taskId==task.id&&c.status==HabitTaskCompletionStatus.completed&&_sameDate(_dateOnly(c.completedAt),_dateOnly(instant)))
      .fold<double>(0,(sum,c)=>sum+((c.quantity??0).isFinite&&(c.quantity??0)>0?(c.quantity??0):0));

  static bool isResolvedOn(
    HabitTask task,
    Iterable<HabitTaskCompletion> completions,
    DateTime instant,
  ) {
    final date = _dateOnly(instant);
    return isCompletedOn(task,completions,instant)||completions.any(
      (completion) => completion.taskId==task.id&&completion.status==HabitTaskCompletionStatus.skipped&&
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
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
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
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    for (var guard = 0; guard < 3660; guard++) {
      if (!isDueOn(task, cursor)) {
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
        continue;
      }

      if (!isCompletedOn(task, completions, cursor)) break;
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    return streak;
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
