import 'package:core/domain/models/workout_session.dart';

class UnilateralSideToggleResult {
  final WorkoutSet set;
  final bool shouldStartInterSideRest;

  const UnilateralSideToggleResult({
    required this.set,
    required this.shouldStartInterSideRest,
  });
}

/// Pure state transition for recording one side of a unilateral set.
///
/// The shared weight/reps/RIR fields are treated as the values currently typed
/// by the user. When a side is selected they are snapshotted into that side;
/// when it is unselected, only that side's snapshot is cleared.
class UnilateralSetCoordinator {
  const UnilateralSetCoordinator._();

  static UnilateralSideToggleResult toggleSide(
    WorkoutSet current,
    WorkoutSide side, {
    bool sameWeightForBothSides = false,
  }) {
    final wasSelected = current.completedForSide(side);
    final select = !wasSelected;

    double snapshotWeight = current.weight;
    if (select && sameWeightForBothSides) {
      if (side == WorkoutSide.left && current.rightCompleted) {
        snapshotWeight = current.weightForSide(WorkoutSide.right);
      } else if (side == WorkoutSide.right && current.leftCompleted) {
        snapshotWeight = current.weightForSide(WorkoutSide.left);
      }
    }

    late final WorkoutSet next;
    switch (side) {
      case WorkoutSide.left:
        next = current.copyWith(
          weight: select && sameWeightForBothSides && current.rightCompleted
              ? snapshotWeight
              : current.weight,
          leftCompleted: select,
          rightCompleted: current.rightCompleted,
          leftWeight: select ? snapshotWeight : null,
          leftReps: select ? current.reps : null,
          leftRir: select ? current.rir : null,
          clearLeftRir: select && current.rir == null,
          clearLeftPerformance: !select,
          completed: select && current.rightCompleted,
        );
        break;
      case WorkoutSide.right:
        next = current.copyWith(
          weight: select && sameWeightForBothSides && current.leftCompleted
              ? snapshotWeight
              : current.weight,
          leftCompleted: current.leftCompleted,
          rightCompleted: select,
          rightWeight: select ? snapshotWeight : null,
          rightReps: select ? current.reps : null,
          rightRir: select ? current.rir : null,
          clearRightRir: select && current.rir == null,
          clearRightPerformance: !select,
          completed: current.leftCompleted && select,
        );
        break;
    }

    return UnilateralSideToggleResult(
      set: next,
      shouldStartInterSideRest:
          select && !next.completed && next.sideRestSeconds > 0,
    );
  }

  static WorkoutSide? recommendedFirstSide({
    required WorkoutSide? preferred,
    required WorkoutSet set,
  }) {
    if (set.leftCompleted || set.rightCompleted) return null;
    return preferred;
  }
}
