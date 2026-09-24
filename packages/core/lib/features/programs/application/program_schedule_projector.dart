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
    // No configured weekdays means the program is sequence-only and can be
    // started on any day rather than becoming impossible to launch.
    return weekdays.isEmpty || weekdays.contains(date.weekday);
  }

  static List<ProgramScheduledSession> project({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required DateTime from,
    required int days,
  }) {
    if (days <= 0 || program.routineIds.isEmpty) {
      return const <ProgramScheduledSession>[];
    }

    final weekdays = effectiveTrainingWeekdays(program, routines);
    final result = <ProgramScheduledSession>[];
    var rotationIndex = program.normalizedNextRotationIndex;
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
}
