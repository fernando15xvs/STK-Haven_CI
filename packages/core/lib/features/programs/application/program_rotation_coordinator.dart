import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';

class ProgramRotationCoordinator {
  const ProgramRotationCoordinator._();

  /// Replays workout history after program start and advances only when the
  /// completed routine matches the program's expected next slot.
  ///
  /// This makes rotation deterministic and independent from weekday scheduling.
  /// Free workouts or out-of-order routine sessions remain valid history but do
  /// not silently mutate A→B→C sequencing.
  static TrainingProgram reconcile(
    TrainingProgram program,
    Iterable<WorkoutSession> history,
  ) {
    if (!program.isActive || program.routineIds.isEmpty) return program;

    final alreadyRecorded = program.completions
        .map((completion) => completion.workoutSessionId)
        .toSet();
    final candidates = history
        .where((session) =>
            !session.startedAt.isBefore(program.startedAt) &&
            (program.sequenceEffectiveAt == null ||
                !session.startedAt.isBefore(program.sequenceEffectiveAt!)) &&
            session.routineId != null &&
            _isCompletedEffectiveSession(session) &&
            !alreadyRecorded.contains(session.id))
        .toList(growable: false)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final completions = List<ProgramCompletion>.from(program.completions);
    final seenSessionIds = <String>{...alreadyRecorded};
    var nextIndex = program.normalizedNextRotationIndex;
    var changed = false;

    // An out-of-order workout skipped in an earlier reconciliation must not
    // become the "next" program session merely because the expected workout
    // was recorded later. Continuous/flexible rotations are append-only in
    // chronological completion order. Historical sessions remain untouched.
    DateTime? latestSequenceCompletion;
    if (program.scheduleMode != ProgramScheduleMode.fixed) {
      for (final completion in program.completions) {
        if (latestSequenceCompletion == null ||
            completion.completedAt.isAfter(latestSequenceCompletion)) {
          latestSequenceCompletion = completion.completedAt;
        }
      }
    }

    for (final session in candidates) {
      final routineId = session.routineId;
      if (routineId == null) continue;
      if (!seenSessionIds.add(session.id)) continue;

      if (program.scheduleMode == ProgramScheduleMode.fixed) {
        final expectedRoutine =
            program.fixedWeekdayRoutineIds[session.startedAt.toLocal().weekday];
        if (expectedRoutine == null || routineId != expectedRoutine) {
          continue;
        }

        final routineIndex = program.routineIds.indexOf(routineId);
        completions.add(
          ProgramCompletion(
            workoutSessionId: session.id,
            routineId: routineId,
            completedAt: session.finishedAt,
            rotationIndex: routineIndex < 0 ? 0 : routineIndex,
            programWeek: program.weekAt(session.finishedAt),
          ),
        );
        changed = true;
        continue;
      }

      if (latestSequenceCompletion != null &&
          session.startedAt.isBefore(latestSequenceCompletion)) {
        // Do not backfill a formerly off-sequence session behind a saved
        // completion. This is especially important when the app reopens and
        // reconciles the same complete workout history again.
        continue;
      }

      if (program.repeatsWeekly) {
        final current = program.copyWith(completions: completions);
        final updated = current.recordCompletion(workoutSessionId: session.id,
            routineId: routineId, completedAt: session.finishedAt);
        if (updated.completions.length == completions.length) continue;
        completions.add(updated.completions.last);
        latestSequenceCompletion = session.finishedAt;
        changed = true;
        continue;
      }

      final expectedRoutine = program.routineIds[nextIndex];
      if (routineId != expectedRoutine) {
        // Off-sequence sessions remain valid workout history but do not advance
        // continuous/flexible sequencing.
        continue;
      }

      completions.add(
        ProgramCompletion(
          workoutSessionId: session.id,
          routineId: routineId,
          completedAt: session.finishedAt,
          rotationIndex: nextIndex,
          programWeek: program.weekAt(session.finishedAt),
        ),
      );
      nextIndex = (nextIndex + 1) % program.routineIds.length;
      latestSequenceCompletion = session.finishedAt;
      changed = true;
    }

    if (!changed) return program;
    return program.copyWith(
      nextRotationIndex: nextIndex,
      completions: List<ProgramCompletion>.unmodifiable(completions),
    );
  }

  static bool _isCompletedEffectiveSession(WorkoutSession session) {
    final effectiveSets = session.exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.setType == WorkoutSetType.working)
        .toList(growable: false);
    return effectiveSets.isNotEmpty &&
        effectiveSets.every((set) => set.completed);
  }

  static String? nextRoutineId(
    TrainingProgram program,
    Iterable<WorkoutSession> history,
  ) {
    return reconcile(program, history).nextRoutineIdAt(DateTime.now());
  }
}
