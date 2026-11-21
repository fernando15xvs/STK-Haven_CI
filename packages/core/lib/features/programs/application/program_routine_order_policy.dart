import 'package:core/domain/models/training_program.dart';

/// Non-destructive edit rules for a program's ordered routine IDs.
///
/// Historical ProgramCompletion rows retain the original program order. A UI
/// reorder must preserve the *identity* of the next pending workout rather
/// than carrying an old numeric index into a new list.
class ProgramRoutineOrderPolicy {
  const ProgramRoutineOrderPolicy._();

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
