import 'package:core/domain/models/workout_session.dart';

class PlateauDetector {
  /// Verifica si el usuario se ha estancado en un ejercicio.
  /// Un estancamiento se define como 3 sesiones consecutivas sin progreso en
  /// el mejor set. El historial es global por exerciseId, no por rutina.
  static bool hasPlateaued({
    required List<WorkoutSession> history,
    required String exerciseId,
    required int targetRepsMin,
    int sessionsToCheck = 3,
  }) {
    final relevantSessions = history.where((session) {
      final exercise = session.exercises
          .where((item) => item.exerciseId == exerciseId)
          .firstOrNull;
      if (exercise == null) return false;
      return exercise.sets.any((set) => set.completed && !set.warmup);
    }).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    if (relevantSessions.length < sessionsToCheck) return false;

    final lastSessions = relevantSessions.sublist(
      relevantSessions.length - sessionsToCheck,
    );
    final bestSets = lastSessions
        .map((session) => _getBestSet(session, exerciseId))
        .toList(growable: false);

    for (var index = 0; index < bestSets.length - 1; index++) {
      if (_hasProgress(bestSets[index], bestSets[index + 1], targetRepsMin)) {
        return false;
      }
    }
    return true;
  }

  static WorkoutSet _getBestSet(WorkoutSession session, String exerciseId) {
    final exercise = session.exercises
        .firstWhere((item) => item.exerciseId == exerciseId);
    final validSets = exercise.sets
        .where((set) => set.completed && !set.warmup)
        .toList(growable: false);

    if (validSets.isEmpty) {
      throw StateError('No valid sets found');
    }

    return validSets.reduce((best, current) {
      if (current.performanceWeight > best.performanceWeight) return current;
      final sameWeight =
          (current.performanceWeight - best.performanceWeight).abs() <= 0.01;
      if (sameWeight && current.performanceReps > best.performanceReps) {
        return current;
      }
      if (sameWeight &&
          current.performanceReps == best.performanceReps &&
          (current.performanceRir ?? 0) > (best.performanceRir ?? 0)) {
        return current;
      }
      return best;
    });
  }

  static bool _hasProgress(
    WorkoutSet previous,
    WorkoutSet current,
    int targetRepsMin,
  ) {
    final previousWeight = previous.performanceWeight;
    final currentWeight = current.performanceWeight;
    final weightUp = currentWeight > previousWeight + 0.01;
    final sameWeight = (currentWeight - previousWeight).abs() <= 0.01;

    if (weightUp && current.performanceReps >= targetRepsMin) return true;
    if (sameWeight && current.performanceReps > previous.performanceReps) {
      return true;
    }
    if (sameWeight &&
        current.performanceReps == previous.performanceReps &&
        (current.performanceRir ?? 0) > (previous.performanceRir ?? 0)) {
      return true;
    }
    return false;
  }
}
