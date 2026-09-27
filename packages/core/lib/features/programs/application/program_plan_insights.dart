import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';

class ProgramPlanInsights {
  final int plannedThisWeek;
  final int completedThisWeek;
  final int dueThroughToday;
  final int pendingDue;
  final int remainingThisWeek;
  final DateTime? nextScheduledDate;
  final String? nextScheduledRoutineId;
  final DateTime estimatedEndDate;
  final Map<String, int> next14RoutineCounts;
  final int next14SessionCount;
  final Set<int> trainingWeekdays;

  const ProgramPlanInsights({
    required this.plannedThisWeek,
    required this.completedThisWeek,
    required this.dueThroughToday,
    required this.pendingDue,
    required this.remainingThisWeek,
    required this.nextScheduledDate,
    required this.nextScheduledRoutineId,
    required this.estimatedEndDate,
    required this.next14RoutineCounts,
    required this.next14SessionCount,
    required this.trainingWeekdays,
  });

  double? get weeklyCompletionRatio {
    if (plannedThisWeek <= 0) return null;
    return (completedThisWeek / plannedThisWeek).clamp(0.0, 1.0);
  }

  String get paceLabel {
    if (plannedThisWeek == 0) {
      return 'No hay sesiones programadas esta semana.';
    }
    if (pendingDue > 0) {
      return pendingDue == 1
          ? 'Tienes 1 sesión pendiente según tu calendario.'
          : 'Tienes $pendingDue sesiones pendientes según tu calendario.';
    }
    if (remainingThisWeek == 0) {
      return 'Completaste lo previsto para esta semana.';
    }
    return 'Vas al día con tu calendario.';
  }

  static ProgramPlanInsights calculate({
    required TrainingProgram program,
    required Iterable<Routine> routines,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final weekStart =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final plannedWeek = ProgramScheduleProjector.projectWeek(
      program: program,
      routines: routines,
      weekStart: weekStart,
    );

    final completedThisWeek = program.completions.where((item) {
      final completed = item.completedAt.toLocal();
      return !completed.isBefore(weekStart) && completed.isBefore(weekEnd);
    }).length;

    final dueThroughToday = plannedWeek
        .where((item) => !item.date.isAfter(today))
        .length;

    final nextSessions = ProgramScheduleProjector.project(
      program: program,
      routines: routines,
      from: today,
      days: 21,
      initialRotationIndex:
          ProgramScheduleProjector.rotationIndexAt(program, now),
    );
    final next = nextSessions.isEmpty ? null : nextSessions.first;

    final next14 = ProgramScheduleProjector.project(
      program: program,
      routines: routines,
      from: today,
      days: 14,
      initialRotationIndex:
          ProgramScheduleProjector.rotationIndexAt(program, now),
    );
    final counts = <String, int>{};
    for (final item in next14) {
      counts[item.routineId] = (counts[item.routineId] ?? 0) + 1;
    }

    final estimatedEndDate = DateTime(
      program.startedAt.year,
      program.startedAt.month,
      program.startedAt.day,
    ).add(
      Duration(
        days: (program.durationWeeks * 7 - 1).clamp(0, 36500).toInt(),
      ),
    );

    return ProgramPlanInsights(
      plannedThisWeek: plannedWeek.length,
      completedThisWeek: completedThisWeek.clamp(0, plannedWeek.length),
      dueThroughToday: dueThroughToday,
      pendingDue:
          (dueThroughToday - completedThisWeek).clamp(0, 999).toInt(),
      remainingThisWeek:
          (plannedWeek.length - completedThisWeek).clamp(0, 999).toInt(),
      nextScheduledDate: next?.date,
      nextScheduledRoutineId: next?.routineId,
      estimatedEndDate: estimatedEndDate,
      next14RoutineCounts: Map<String, int>.unmodifiable(counts),
      next14SessionCount: next14.length,
      trainingWeekdays:
          ProgramScheduleProjector.effectiveTrainingWeekdays(
        program,
        routines,
      ),
    );
  }
}
