import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';

class ProgramScheduledSession {
  final DateTime date;
  final String routineId;
  final int rotationIndex;

  const ProgramScheduledSession({
    required this.date,
    required this.routineId,
    required this.rotationIndex,
  });
}

class ProgramScheduleProjector {
  const ProgramScheduleProjector._();

  static Set<int> recommendedTrainingWeekdays(int daysPerWeek) {
    return switch (daysPerWeek) {
      <= 1 => <int>{DateTime.monday},
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

  static Set<int> effectiveTrainingWeekdays(
    TrainingProgram program,
    Iterable<Routine> routines,
  ) {
    if (program.trainingWeekdays.isNotEmpty) {
      return Set<int>.from(program.trainingWeekdays);
    }

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

  static bool isTrainingDay(
    TrainingProgram program,
    Iterable<Routine> routines,
    DateTime date,
  ) {
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

    final weekdays = effectiveTrainingWeekdays(program, routines);
    final result = <ProgramScheduledSession>[];
    var rotationIndex =
        (initialRotationIndex ?? program.normalizedNextRotationIndex) %
            program.routineIds.length;
    var cursor = DateTime(from.year, from.month, from.day);

    for (var offset = 0; offset < days; offset++) {
      final isOpportunity =
          weekdays.isEmpty || weekdays.contains(cursor.weekday);
      if (isOpportunity) {
        result.add(
          ProgramScheduledSession(
            date: cursor,
            routineId: program.routineIds[rotationIndex],
            rotationIndex: rotationIndex,
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
