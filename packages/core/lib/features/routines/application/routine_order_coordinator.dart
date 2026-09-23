import '../../../domain/models/routine.dart';

/// Keeps routine exercise ordering deterministic across mobile and web.
///
/// Reordering never reconstructs an exercise from scratch, so every existing
/// configuration (including supersets, warmups, approach sets and unilateral
/// settings) is preserved. Only the `order` field is rewritten.
class RoutineOrderCoordinator {
  const RoutineOrderCoordinator._();

  static List<RoutineExercise> move(
    List<RoutineExercise> exercises,
    int fromIndex,
    int toIndex,
  ) {
    if (exercises.isEmpty ||
        fromIndex < 0 ||
        fromIndex >= exercises.length ||
        toIndex < 0 ||
        toIndex >= exercises.length ||
        fromIndex == toIndex) {
      return normalize(exercises);
    }

    final reordered = List<RoutineExercise>.from(exercises);
    final item = reordered.removeAt(fromIndex);
    reordered.insert(toIndex, item);
    return normalize(reordered);
  }

  static List<RoutineExercise> normalize(List<RoutineExercise> exercises) {
    return List<RoutineExercise>.generate(
      exercises.length,
      (index) => exercises[index].copyWith(order: index),
      growable: false,
    );
  }
}
