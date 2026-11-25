import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_week_plan.dart';

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
  final ProgramScheduleMode scheduleMode;
  final int targetSessionsPerWeek;
  final ProgramWeekPlan? weekPlan;
  bool get weeklyGoalReached => plannedThisWeek > 0 && remainingThisWeek == 0;

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
    required this.scheduleMode,
    required this.targetSessionsPerWeek,
    this.weekPlan,
  });

  double? get weeklyCompletionRatio {
    if (plannedThisWeek <= 0) return null;
    return (completedThisWeek / plannedThisWeek).clamp(0.0, 1.0);
  }

  String get paceLabel {
    if (scheduleMode == ProgramScheduleMode.flexible) {
      if (remainingThisWeek == 0) {
        return 'Completaste tu frecuencia objetivo de esta semana.';
      }
      return 'Llevas $completedThisWeek de $targetSessionsPerWeek sesiones objetivo.';
    }
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
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final weekStart = TrainingProgram.localWeekStart(local);

    final plannedWeek = ProgramScheduleProjector.projectWeek(
      program: program,
      routines: routines,
      weekStart: weekStart,
    );

    final rawCompletedThisWeek = program.completionsInLocalWeek(local)
        .where((item) => !item.completedAt.isAfter(now)).length;
    final targetFrequency = ProgramScheduleProjector.effectiveTargetSessionsPerWeek(
      program,
      routines,
    );
    final plannedThisWeek = program.scheduleMode == ProgramScheduleMode.flexible
        ? targetFrequency
        : plannedWeek.length;
    final completedThisWeek =
        rawCompletedThisWeek.clamp(0, plannedThisWeek).toInt();

    final dueThroughToday =
        program.scheduleMode == ProgramScheduleMode.flexible
            ? 0
            : plannedWeek
                .where((item) => !item.date.isAfter(today))
                .length;

    final weekPlan = ProgramWeekPlan.calculate(program: program, routines: routines, now: now);
    final next = weekPlan.nextSuggestion;

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

    final pauseDuration = program.adaptation?.pausedDuration(program.startedAt, now) ?? Duration.zero;
    final estimatedEndDate = DateTime(
      program.startedAt.year,
      program.startedAt.month,
      program.startedAt.day,
    ).add(
      Duration(
        days: (program.durationWeeks * 7 - 1 + pauseDuration.inDays).clamp(0, 36500).toInt(),
      ),
    );

    return ProgramPlanInsights(
      plannedThisWeek: plannedThisWeek,
      completedThisWeek: completedThisWeek,
      dueThroughToday: dueThroughToday,
      pendingDue:
          (dueThroughToday - completedThisWeek).clamp(0, 999).toInt(),
      remainingThisWeek:
          (plannedThisWeek - completedThisWeek).clamp(0, 999).toInt(),
      nextScheduledDate:
          program.scheduleMode == ProgramScheduleMode.flexible
              ? null
              : next?.date,
      nextScheduledRoutineId: next?.routineId,
      weekPlan: weekPlan,
      estimatedEndDate: estimatedEndDate,
      next14RoutineCounts: Map<String, int>.unmodifiable(counts),
      next14SessionCount: next14.length,
      trainingWeekdays:
          ProgramScheduleProjector.effectiveTrainingWeekdays(
        program,
        routines,
      ),
      scheduleMode: program.scheduleMode,
      targetSessionsPerWeek: targetFrequency,
    );
  }
}
