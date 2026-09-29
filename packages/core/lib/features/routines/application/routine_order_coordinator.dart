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
    final indexed = exercises.asMap().entries.toList(growable: false)
      ..sort((a, b) {
        final phase = a.value.phase.sortOrder.compareTo(b.value.phase.sortOrder);
        if (phase != 0) return phase;
        return a.key.compareTo(b.key);
      });

    return List<RoutineExercise>.generate(
      indexed.length,
      (index) => indexed[index].value.copyWith(order: index),
      growable: false,
    );
  }
}
