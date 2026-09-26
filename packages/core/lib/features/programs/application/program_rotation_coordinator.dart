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
            session.routineId != null &&
            !alreadyRecorded.contains(session.id))
        .toList(growable: false)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final completions = List<ProgramCompletion>.from(program.completions);
    var nextIndex = program.normalizedNextRotationIndex;
    var changed = false;

    for (final session in candidates) {
      final routineId = session.routineId;
      if (routineId == null) continue;
      if (!alreadyRecorded.add(session.id)) continue;

      final expectedRoutine = program.routineIds[nextIndex];
      if (routineId != expectedRoutine) {
        // Off-sequence sessions remain valid workout history but do not advance
        // the expected program rotation.
        alreadyRecorded.remove(session.id);
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
      changed = true;
    }

    if (!changed) return program;
    return program.copyWith(
      nextRotationIndex: nextIndex,
      completions: List<ProgramCompletion>.unmodifiable(completions),
    );
  }

  static String? nextRoutineId(
    TrainingProgram program,
    Iterable<WorkoutSession> history,
  ) {
    return reconcile(program, history).nextRoutineId;
  }
}
