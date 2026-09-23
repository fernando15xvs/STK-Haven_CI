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

    var next = program;
    for (final session in candidates) {
      final routineId = session.routineId;
      if (routineId == null) continue;
      next = next.recordCompletion(
        workoutSessionId: session.id,
        routineId: routineId,
        completedAt: session.finishedAt,
      );
    }
    return next;
  }

  static String? nextRoutineId(
    TrainingProgram program,
    Iterable<WorkoutSession> history,
  ) {
    return reconcile(program, history).nextRoutineId;
  }
}
