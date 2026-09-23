import 'dart:math' as math;

import 'package:core/domain/models/workout_session.dart';

class SupersetRestDecision {
  final bool shouldStartRest;
  final int restSeconds;

  const SupersetRestDecision({
    required this.shouldStartRest,
    required this.restSeconds,
  });
}

/// Decide cuándo debe comenzar el descanso automático en una superserie.
///
/// Solo coordina series de trabajo. Calentamiento y aproximación mantienen
/// su comportamiento tradicional. Para series de trabajo, la primera mitad
/// de la ronda no inicia descanso; la segunda sí.
class SupersetCoordinator {
  const SupersetCoordinator._();

  static SupersetRestDecision restDecision({
    required List<WorkoutExercise> exercises,
    required int exerciseIndex,
    required int setIndex,
  }) {
    final exercise = exercises[exerciseIndex];
    final set = exercise.sets[setIndex];
    final groupId = exercise.supersetGroupId;

    if (set.setType != WorkoutSetType.working || groupId == null) {
      return SupersetRestDecision(
        shouldStartRest: true,
        restSeconds: set.restSeconds,
      );
    }

    WorkoutExercise? partner;
    for (var index = 0; index < exercises.length; index++) {
      if (index == exerciseIndex) continue;
      final candidate = exercises[index];
      if (candidate.supersetGroupId == groupId) {
        partner = candidate;
        break;
      }
    }

    if (partner == null) {
      return SupersetRestDecision(
        shouldStartRest: true,
        restSeconds: set.restSeconds,
      );
    }

    var workingOrdinal = -1;
    for (var index = 0; index <= setIndex; index++) {
      if (exercise.sets[index].setType == WorkoutSetType.working) {
        workingOrdinal++;
      }
    }

    final partnerWorkingSets = partner.sets
        .where((candidate) => candidate.setType == WorkoutSetType.working)
        .toList(growable: false);

    if (workingOrdinal < 0 || workingOrdinal >= partnerWorkingSets.length) {
      return SupersetRestDecision(
        shouldStartRest: true,
        restSeconds: set.restSeconds,
      );
    }

    final partnerSet = partnerWorkingSets[workingOrdinal];
    if (!partnerSet.completed) {
      return const SupersetRestDecision(
        shouldStartRest: false,
        restSeconds: 0,
      );
    }

    return SupersetRestDecision(
      shouldStartRest: true,
      restSeconds: math.max(set.restSeconds, partnerSet.restSeconds),
    );
  }
}
