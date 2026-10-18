import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/domain/models/exercise.dart';

/// Read-only anatomy browsing. Neither this class nor the filter writes to Hive
/// or changes historical exercise labels, IDs, PRs, routines or snapshots.
class MuscleHierarchyBrowser {
  const MuscleHierarchyBrowser._();

  /// Roots or immediate children, including cross-listed muscles once per ID.
  static List<MuscleNode> childrenOf(String? parentId) {
    if (parentId != null && !MuscleTaxonomyV1.byId.containsKey(parentId)) {
      return const <MuscleNode>[];
    }
    return List<MuscleNode>.unmodifiable(
      MuscleTaxonomyV1.nodes.where((node) =>
          node.parentId == parentId ||
          (parentId != null && node.crossListedUnder.contains(parentId))),
    );
  }

  /// Canonical breadcrumb path, without cross-listing duplicates.
  static List<MuscleNode> pathTo(String? nodeId) {
    final result = <MuscleNode>[];
    final visited = <String>{};
    var current = nodeId;
    while (current != null && visited.add(current)) {
      final node = MuscleTaxonomyV1.byId[current];
      if (node == null) break;
      result.add(node);
      current = node.parentId;
    }
    return List<MuscleNode>.unmodifiable(result.reversed);
  }

  /// Uses only known anatomical IDs. A broad legacy label such as "Hombros"
  /// matches the general shoulder category, never a deltoid portion. Combined
  /// and unrecognised labels do not silently acquire a specific muscle.
  static bool matchesExercise(Exercise exercise, String selectedId) {
    final selected = MuscleTaxonomyV1.byId[selectedId];
    if (selected == null) return false;
    for (final label in <String>[
      exercise.muscleGroup,
      ...exercise.secondaryMuscles,
    ]) {
      final resolved = MuscleTaxonomyV1.resolveLegacy(label);
      final targetId = resolved.nodeId;
      if (targetId == null) continue;
      if (targetId == selectedId) return true;
      if (selected.isCategory &&
          MuscleTaxonomyV1.belongsToGroup(targetId, selectedId)) {
        return true;
      }
    }
    return false;
  }
}
