import '../../../domain/models/routine.dart';

/// Moves one scheduled routine occurrence without changing the routine itself.
///
/// Days use [DateTime.weekday] values (1 = Monday, 7 = Sunday). The remaining
/// scheduled days, exercises, notes and advanced exercise configuration are
/// preserved.
class RoutineScheduleCoordinator {
  const RoutineScheduleCoordinator._();

  static Routine moveToDay({
    required Routine routine,
    required int fromDay,
    required int toDay,
  }) {
    _validateWeekday(fromDay, 'fromDay');
    _validateWeekday(toDay, 'toDay');

    if (fromDay == toDay || !routine.scheduledDays.contains(fromDay)) {
      return routine;
    }

    final updatedDays = routine.scheduledDays
        .where((day) => day != fromDay)
        .toSet()
      ..add(toDay);
    final scheduledDays = updatedDays.toList()..sort();

    return routine.copyWith(scheduledDays: scheduledDays);
  }

  static void _validateWeekday(int day, String name) {
    if (day < DateTime.monday || day > DateTime.sunday) {
      throw RangeError.range(
        day,
        DateTime.monday,
        DateTime.sunday,
        name,
      );
    }
  }
}
