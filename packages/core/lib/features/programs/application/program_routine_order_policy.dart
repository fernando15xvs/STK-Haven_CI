import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/program_adaptation.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';

/// Non-destructive edit rules for a program's ordered routine IDs.
///
/// Historical ProgramCompletion rows retain the original program order. A UI
/// reorder must preserve the *identity* of the next pending workout rather
/// than carrying an old numeric index into a new list.
class ProgramRoutineOrderPolicy {
  const ProgramRoutineOrderPolicy._();

  static List<String> normalizeWeeklySlots(List<String> routineIds,
      List<String> slots, int target) {
    final count = target.clamp(0, 7).toInt();
    final valid = slots.where(routineIds.contains).take(count).toList();
    return List.unmodifiable([
      ...valid,
      if (routineIds.isNotEmpty)
        for (var i = valid.length; i < count; i++) routineIds[i % routineIds.length],
    ]);
  }

  /// Template preview, not a forecast of a user's completed history.
  static List<List<String>> previewWeeks(List<String> routineIds,
      List<String> weeklySlots, int target, ProgramSequencePolicy policy) {
    if (routineIds.isEmpty || target <= 0) return const [];
    final count = target.clamp(1, 7).toInt();
    return [
      for (var week = 0; week < 2; week++)
        if (policy == ProgramSequencePolicy.weekly)
          normalizeWeeklySlots(routineIds, weeklySlots, count)
        else
          List.generate(count, (i) => routineIds[(week * count + i) % routineIds.length]),
    ];
  }

  static bool scheduleChanged(TrainingProgram a, TrainingProgram b) {
    bool sameList(List<String> x, List<String> y) =>
        x.length == y.length && x.indexed.every((entry) => y[entry.$1] == entry.$2);
    return a.scheduleMode != b.scheduleMode ||
        a.sequencePolicy != b.sequencePolicy ||
        a.targetSessionsPerWeek != b.targetSessionsPerWeek ||
        !sameList(a.routineIds, b.routineIds) ||
        !sameList(a.weeklySequenceRoutineIds, b.weeklySequenceRoutineIds) ||
        a.trainingWeekdays.length != b.trainingWeekdays.length ||
        !a.trainingWeekdays.containsAll(b.trainingWeekdays) ||
        a.fixedWeekdayRoutineIds.length != b.fixedWeekdayRoutineIds.length ||
        a.fixedWeekdayRoutineIds.entries.any((entry) =>
            b.fixedWeekdayRoutineIds[entry.key] != entry.value);
  }

  /// Validate newly authored weekly sequences at the write boundary. Legacy
  /// payloads still load through the model's non-destructive fallback.
  static void validateWeeklyConfiguration(TrainingProgram program) {
    if (!program.repeatsWeekly) return;
    final target = program.scheduleMode == ProgramScheduleMode.continuous &&
            program.trainingWeekdays.isNotEmpty
        ? program.trainingWeekdays.length : program.targetSessionsPerWeek;
    if (target < 1 || target > 7 ||
        program.weeklySequenceRoutineIds.length != target ||
        program.routineIds.toSet().length != program.routineIds.length ||
        !program.weeklySequenceRoutineIds.every(program.routineIds.contains)) {
      throw ArgumentError('La secuencia semanal debe contener una rutina válida por sesión objetivo.');
    }
  }

  /// Apply an edit against reconciled persisted progress, not the stale editor
  /// snapshot. Only future interpretation changes; history is never rewritten.
  static TrainingProgram applyScheduleEdit({
    required TrainingProgram existing,
    required TrainingProgram edited,
    required DateTime now,
    Iterable<Routine> routines = const [],
  }) {
    final changed = scheduleChanged(existing, edited);
    final normalized = edited.repeatsWeekly &&
        edited.weeklySequenceRoutineIds.isNotEmpty &&
        existing.weeklySequenceRoutineIds.length == edited.weeklySequenceRoutineIds.length &&
        existing.weeklySequenceRoutineIds.indexed.every((entry) =>
            edited.weeklySequenceRoutineIds[entry.$1] == entry.$2) &&
        existing.repeatsWeekly
        ? edited.copyWith(weeklySequenceRoutineIds: edited.weeklySequence)
        : edited;
    if (changed) validateWeeklyConfiguration(normalized);
    final compatibleCalendarChange = changed && existing.adaptation != null &&
        existing.scheduleMode != ProgramScheduleMode.fixed && normalized.scheduleMode != ProgramScheduleMode.fixed &&
        existing.sequencePolicy == normalized.sequencePolicy &&
        existing.routineIds.length == normalized.routineIds.length &&
        existing.routineIds.indexed.every((e) => normalized.routineIds[e.$1] == e.$2) &&
        existing.weeklySequenceRoutineIds.length == normalized.weeklySequenceRoutineIds.length &&
        existing.weeklySequenceRoutineIds.indexed.every((e) => normalized.weeklySequenceRoutineIds[e.$1] == e.$2) &&
        ProgramScheduleProjector.effectiveTargetSessionsPerWeek(existing, routines) ==
          ProgramScheduleProjector.effectiveTargetSessionsPerWeek(normalized, routines);
    if (compatibleCalendarChange) {
      return ProgramAdaptationPolicy.prepare(normalized.copyWith(startedAt: existing.startedAt,
        completions: existing.completions, adaptation: existing.adaptation,
        nextRotationIndex: existing.nextRotationIndex, sequenceEffectiveAt: now), routines, now);
    }
    var pointer = nextIndexAfterEdit(existing: existing,
        updatedRoutineIds: normalized.routineIds);
    if (changed && existing.adaptation != null) {
      // The adapted pointer reserves future slots. Anchor an edit at the first
      // unresolved surviving occurrence, not at that reservation cursor.
      for (final o in existing.adaptation!.occurrences) {
        if (!o.archived && o.week == existing.adaptation!.week &&
            o.status == PlanOccurrenceStatus.pending) {
          final index = normalized.routineIds.indexOf(o.routineId);
          if (index >= 0) { pointer = index; break; }
        }
      }
    }
    final result = normalized.copyWith(
      startedAt: existing.startedAt,
      completions: existing.completions,
      adaptation: existing.adaptation,
      nextRotationIndex: pointer,
      sequenceEffectiveAt: changed ? now : existing.sequenceEffectiveAt,
    );
    return changed && existing.adaptation != null
        ? ProgramAdaptationPolicy.rebase(existing, result, routines, now) : result;
  }

  static int nextIndexAfterEdit({
    required TrainingProgram existing,
    required List<String> updatedRoutineIds,
  }) {
    if (updatedRoutineIds.isEmpty || existing.routineIds.isEmpty) return 0;

    final selected = existing.nextRoutineId;
    if (selected != null) {
      final retained = updatedRoutineIds.indexOf(selected);
      if (retained >= 0) return retained;
    }

    // If the next routine was removed, advance from the old pointer to
    // the nearest surviving routine in the original cycle. Never map the
    // numeric pointer to an unrelated exercise.
    final prior = existing.routineIds;
    for (var offset = 1; offset <= prior.length; offset++) {
      final oldIndex =
          (existing.normalizedNextRotationIndex + offset) % prior.length;
      final candidate = updatedRoutineIds.indexOf(prior[oldIndex]);
      if (candidate >= 0) return candidate;
    }

    // All old routines removed: the user explicitly authored a fresh order.
    return 0;
  }
}
