import 'package:core/domain/models/routine.dart';

/// Pure helpers for maintaining the invariant that a routine superset is a
/// pair of exactly two exercises.
class RoutineSupersetCoordinator {
  const RoutineSupersetCoordinator._();

  static List<RoutineExercise> pair(
    List<RoutineExercise> exercises,
    int firstIndex,
    int secondIndex,
    String groupId,
  ) {
    if (firstIndex == secondIndex ||
        firstIndex < 0 ||
        secondIndex < 0 ||
        firstIndex >= exercises.length ||
        secondIndex >= exercises.length) {
      return List<RoutineExercise>.from(exercises);
    }

    final firstGroup = exercises[firstIndex].supersetGroupId;
    final secondGroup = exercises[secondIndex].supersetGroupId;
    final groupsToClear = <String>{
      if (firstGroup != null) firstGroup,
      if (secondGroup != null) secondGroup,
    };

    final result = exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      final shouldClear = exercise.supersetGroupId != null &&
          groupsToClear.contains(exercise.supersetGroupId);
      final cleaned = shouldClear
          ? exercise.copyWith(clearSupersetGroupId: true)
          : exercise;
      if (index == firstIndex || index == secondIndex) {
        return cleaned.copyWith(supersetGroupId: groupId);
      }
      return cleaned;
    }).toList(growable: false);

    return normalize(result);
  }

  static List<RoutineExercise> unpair(
    List<RoutineExercise> exercises,
    int index,
  ) {
    if (index < 0 || index >= exercises.length) {
      return List<RoutineExercise>.from(exercises);
    }
    final groupId = exercises[index].supersetGroupId;
    if (groupId == null) return List<RoutineExercise>.from(exercises);

    return exercises
        .map(
          (exercise) => exercise.supersetGroupId == groupId
              ? exercise.copyWith(clearSupersetGroupId: true)
              : exercise,
        )
        .toList(growable: false);
  }

  static List<RoutineExercise> normalize(List<RoutineExercise> exercises) {
    final counts = <String, int>{};
    for (final exercise in exercises) {
      final groupId = exercise.supersetGroupId;
      if (groupId != null) {
        counts[groupId] = (counts[groupId] ?? 0) + 1;
      }
    }

    return exercises
        .map((exercise) {
          final groupId = exercise.supersetGroupId;
          if (groupId == null || counts[groupId] == 2) return exercise;
          return exercise.copyWith(clearSupersetGroupId: true);
        })
        .toList(growable: false);
  }

  static Map<String, List<int>> groups(List<RoutineExercise> exercises) {
    final groups = <String, List<int>>{};
    for (var index = 0; index < exercises.length; index++) {
      final groupId = exercises[index].supersetGroupId;
      if (groupId != null) {
        groups.putIfAbsent(groupId, () => <int>[]).add(index);
      }
    }
    groups.removeWhere((_, indexes) => indexes.length != 2);
    return groups;
  }
}
