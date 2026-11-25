import 'package:core/domain/models/training_program.dart';

/// Non-destructive edit rules for a program's ordered routine IDs.
///
/// Historical ProgramCompletion rows retain the original program order. A UI
/// reorder must preserve the *identity* of the next pending workout rather
/// than carrying an old numeric index into a new list.
class ProgramRoutineOrderPolicy {
  const ProgramRoutineOrderPolicy._();

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
    return normalized.copyWith(
      startedAt: existing.startedAt,
      completions: existing.completions,
      nextRotationIndex: nextIndexAfterEdit(existing: existing,
          updatedRoutineIds: normalized.routineIds),
      sequenceEffectiveAt: changed ? now : existing.sequenceEffectiveAt,
    );
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
