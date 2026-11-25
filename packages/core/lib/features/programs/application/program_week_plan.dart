import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';

/// A projection slot is identified by the program, local week and ordinal,
/// never by routine ID alone. Exceptions and explicit workout attribution
/// will extend this projection in block B.
class ProgramWeekSlot {
  const ProgramWeekSlot({required this.id, required this.routineId,
    required this.ordinal, this.date, this.completion});
  final String id;
  final String routineId;
  final int ordinal;
  final DateTime? date;
  final ProgramCompletion? completion;
  bool get isCompleted => completion != null;
}

class ProgramNextSuggestion {
  const ProgramNextSuggestion(this.routineId, {this.date});
  final String routineId;
  final DateTime? date;
}

/// Single date-free flexible projection and calendar-aware suggestion.
/// Future slots are estimates, not obligations or stored completions.
class ProgramWeekPlan {
  const ProgramWeekPlan({required this.weekStart, required this.slots,
    required this.nextWeekRoutineIds, required this.nextSuggestion,
    required this.target, required this.completed});
  final DateTime weekStart;
  final List<ProgramWeekSlot> slots;
  final List<String> nextWeekRoutineIds;
  final ProgramNextSuggestion? nextSuggestion;
  final int target;
  final int completed;
  bool get goalReached => target > 0 && completed >= target;

  static ProgramWeekPlan calculate({required TrainingProgram program,
      required Iterable<Routine> routines, required DateTime now}) {
    final start = TrainingProgram.localWeekStart(now);
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final target = ProgramScheduleProjector.effectiveTargetSessionsPerWeek(program, routines);
    final completed = program.completionsInLocalWeek(now)
        .where((item) => !item.completedAt.isAfter(now)).toList();
    final fixed = program.scheduleMode == ProgramScheduleMode.fixed;
    final weekdays = ProgramScheduleProjector.effectiveTrainingWeekdays(program, routines);
    final hasDates = fixed || (program.scheduleMode == ProgramScheduleMode.continuous &&
        weekdays.isNotEmpty);
    final calendar = hasDates ? ProgramScheduleProjector.projectWeek(
        program: program, routines: routines, weekStart: start) : const <ProgramScheduledSession>[];
    final opportunities = calendar.where((item) => !item.date.isBefore(today)).toList();
    final slots = <ProgramWeekSlot>[];
    void add(String routine, {DateTime? date, ProgramCompletion? completion}) {
      slots.add(ProgramWeekSlot(id: '${program.id}:${start.toIso8601String()}:${slots.length}',
        routineId: routine, ordinal: slots.length, date: date, completion: completion));
    }
    final ids = program.routineIds;
    final remaining = (target - completed.length).clamp(0, 7).toInt();
    final nextWeek = <String>[];
    if (fixed) {
      final matched = <String>{};
      for (final item in calendar) {
        ProgramCompletion? match;
        for (final c in completed) {
          final date = c.completedAt.toLocal();
          if (c.routineId == item.routineId && date.weekday == item.date.weekday &&
              matched.add(c.workoutSessionId)) {
            match = c;
            break;
          }
        }
        add(item.routineId, date: item.date, completion: match);
      }
      // Preserve actual completions whose original weekday was edited.
      for (final c in completed.where((c) => !matched.contains(c.workoutSessionId))) {
        add(c.routineId, completion: c);
      }
      final nextStart = TrainingProgram.shiftCalendarDays(start, 7);
      nextWeek.addAll(ProgramScheduleProjector.projectWeek(program: program,
          routines: routines, weekStart: nextStart).map((item) => item.routineId));
    } else if (ids.isNotEmpty) {
      for (final c in completed) {
        add(c.routineId, completion: c);
      }
      final weekly = program.weeklySequence;
      for (var i = 0; i < remaining; i++) {
        final index = completed.length + i;
        final routineId = program.repeatsWeekly
            ? (index < weekly.length ? weekly[index] : null)
            : ids[(program.normalizedNextRotationIndex + i) % ids.length];
        if (routineId == null) break;
        add(routineId, date: i < opportunities.length ? opportunities[i].date : null);
      }
      if (program.repeatsWeekly) {
        nextWeek.addAll(weekly);
      } else {
        for (var i = 0; i < target; i++) {
          nextWeek.add(ids[(program.normalizedNextRotationIndex + remaining + i) % ids.length]);
        }
      }
    }
    // Keep legacy rolling recommendation semantics until block D exposes the
    // goal-reached state. Weekly mode cannot consume extra sequence positions.
    ProgramNextSuggestion? next;
    if (!hasDates) {
      final id = program.nextRoutineIdAt(now);
      if (id != null) next = ProgramNextSuggestion(id);
    } else if (fixed || ids.isNotEmpty) {
      final projected = ProgramScheduleProjector.project(program: program, routines: routines,
          from: today, days: 21,
          initialRotationIndex: ProgramScheduleProjector.rotationIndexAt(program, now));
      if (projected.isNotEmpty) {
        final item = projected.first;
        next = ProgramNextSuggestion(item.routineId, date: item.date);
      }
    }
    return ProgramWeekPlan(weekStart: start, slots: List.unmodifiable(slots),
      nextWeekRoutineIds: List.unmodifiable(nextWeek), nextSuggestion: next,
      target: target, completed: completed.length);
  }
}
