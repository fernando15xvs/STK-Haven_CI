import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';

class ProgramScheduledSession {
  final DateTime date;
  final String routineId;
  final int rotationIndex;

  /// True when the date is only an internal distribution estimate for a plan
  /// that intentionally has no fixed weekdays.
  final bool isFlexibleEstimate;

  const ProgramScheduledSession({
    required this.date,
    required this.routineId,
    required this.rotationIndex,
    this.isFlexibleEstimate = false,
  });
}

class ProgramScheduleProjector {
  const ProgramScheduleProjector._();

  static Set<int> recommendedTrainingWeekdays(int daysPerWeek) {
    return switch (daysPerWeek.clamp(1, 7)) {
      1 => <int>{DateTime.monday},
      2 => <int>{DateTime.monday, DateTime.thursday},
      3 => <int>{DateTime.monday, DateTime.wednesday, DateTime.friday},
      4 => <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
        },
      5 => <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        },
      6 => <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        },
      _ => <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
    };
  }

  /// Days that the user explicitly owns at plan level.
  ///
  /// Routine schedules are consulted only for legacy continuous programs that
  /// predate plan-level frequency. New plans never inherit routine weekdays
  /// implicitly, which prevents the same schedule from being configured twice.
  static Set<int> effectiveTrainingWeekdays(
    TrainingProgram program,
    Iterable<Routine> routines,
  ) {
    switch (program.scheduleMode) {
      case ProgramScheduleMode.flexible:
        return const <int>{};
      case ProgramScheduleMode.fixed:
        if (program.fixedWeekdayRoutineIds.isNotEmpty) {
          return program.fixedWeekdayRoutineIds.keys
              .where(
                (day) =>
                    day >= DateTime.monday && day <= DateTime.sunday,
              )
              .toSet();
        }
        return Set<int>.from(program.trainingWeekdays);
      case ProgramScheduleMode.continuous:
        if (program.trainingWeekdays.isNotEmpty) {
          return Set<int>.from(program.trainingWeekdays);
        }
        if (program.targetSessionsPerWeek > 0) {
          return const <int>{};
        }

        // Backward compatibility only: old programs stored weekdays on each
        // routine because the plan-level model did not exist yet.
        final routineIds = program.routineIds.toSet();
        final derived = <int>{};
        for (final routine in routines) {
          if (!routineIds.contains(routine.id)) continue;
          for (final day in routine.scheduledDays) {
            if (day >= DateTime.monday && day <= DateTime.sunday) {
              derived.add(day);
            }
          }
        }
        return derived;
    }
  }

  static Set<int> _planningWeekdays(
    TrainingProgram program,
    Iterable<Routine> routines,
  ) {
    final explicit = effectiveTrainingWeekdays(program, routines);
    if (explicit.isNotEmpty) return explicit;

    final target = program.effectiveTargetSessionsPerWeek;
    if (target <= 0) return const <int>{};
    return recommendedTrainingWeekdays(target);
  }

  static bool isTrainingDay(
    TrainingProgram program,
    Iterable<Routine> routines,
    DateTime date,
  ) {
    if (program.scheduleMode == ProgramScheduleMode.flexible) {
      return true;
    }

    final weekdays = effectiveTrainingWeekdays(program, routines);
    return weekdays.isEmpty || weekdays.contains(date.weekday);
  }

  static int rotationIndexAt(
    TrainingProgram program,
    DateTime instant,
  ) {
    if (program.routineIds.isEmpty) return 0;

    final before = program.completions
        .where((item) => item.completedAt.isBefore(instant))
        .toList(growable: false)
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (before.isEmpty) {
      return program.completions.isEmpty
          ? program.normalizedNextRotationIndex
          : 0;
    }

    if (program.scheduleMode == ProgramScheduleMode.fixed) {
      return program.normalizedNextRotationIndex;
    }

    return (before.last.rotationIndex + 1) % program.routineIds.length;
  }

  static List<ProgramScheduledSession> project({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required DateTime from,
    required int days,
    int? initialRotationIndex,
  }) {
    if (days <= 0 || program.routineIds.isEmpty) {
      return const <ProgramScheduledSession>[];
    }

    final result = <ProgramScheduledSession>[];
    var cursor = DateTime(from.year, from.month, from.day);

    if (program.scheduleMode == ProgramScheduleMode.fixed) {
      for (var offset = 0; offset < days; offset++) {
        final routineId = program.fixedWeekdayRoutineIds[cursor.weekday];
        if (routineId != null && program.routineIds.contains(routineId)) {
          final index = program.routineIds.indexOf(routineId);
          result.add(
            ProgramScheduledSession(
              date: cursor,
              routineId: routineId,
              rotationIndex: index < 0 ? 0 : index,
            ),
          );
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      return result;
    }

    final weekdays = _planningWeekdays(program, routines);
    final estimated = program.scheduleMode == ProgramScheduleMode.flexible ||
        (program.scheduleMode == ProgramScheduleMode.continuous &&
            effectiveTrainingWeekdays(program, routines).isEmpty &&
            program.targetSessionsPerWeek > 0);

    var rotationIndex =
        (initialRotationIndex ?? program.normalizedNextRotationIndex) %
            program.routineIds.length;

    for (var offset = 0; offset < days; offset++) {
      final isOpportunity =
          weekdays.isEmpty || weekdays.contains(cursor.weekday);
      if (isOpportunity) {
        result.add(
          ProgramScheduledSession(
            date: cursor,
            routineId: program.routineIds[rotationIndex],
            rotationIndex: rotationIndex,
            isFlexibleEstimate: estimated,
          ),
        );
        rotationIndex = (rotationIndex + 1) % program.routineIds.length;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return result;
  }

  static List<ProgramScheduledSession> projectWeek({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required DateTime weekStart,
  }) {
    if (program.routineIds.isEmpty) {
      return const <ProgramScheduledSession>[];
    }

    final normalizedWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = normalizedWeekStart.add(const Duration(days: 7));
    final programStart = DateTime(
      program.startedAt.year,
      program.startedAt.month,
      program.startedAt.day,
    );
    final from = programStart.isAfter(normalizedWeekStart)
        ? programStart
        : normalizedWeekStart;

    if (!from.isBefore(weekEnd)) {
      return const <ProgramScheduledSession>[];
    }

    return project(
      program: program,
      routines: routines,
      from: from,
      days: weekEnd.difference(from).inDays,
      initialRotationIndex: rotationIndexAt(program, from),
    );
  }
}
