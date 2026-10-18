import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/features/exercises/application/muscle_hierarchy_browser.dart';

enum ExerciseLateralityFilter { all, unilateral, bilateral }

class ExerciseLibraryFilter {
  static const String allOption = 'Todos';

  static List<String> equipmentOptions(Iterable<Exercise> exercises) {
    final values = exercises
        .map((exercise) => exercise.equipment.trim())
        .where((equipment) => equipment.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => _normalize(a).compareTo(_normalize(b)));
    return [allOption, ...values];
  }

  static bool isUnilateral(Exercise exercise) {
    final definition = CuratedExerciseCatalog.byId[exercise.id];
    if (definition != null) return definition.unilateral;
    final text = _normalize(
      '${exercise.name} ${exercise.instructions}',
    );
    const markers = <String>[
      'unilateral',
      'alterno',
      'alternada',
      'alternado',
      'un solo brazo',
      'una sola pierna',
      'un brazo',
      'una pierna',
      'single arm',
      'single leg',
    ];
    return markers.any(text.contains);
  }

  static bool matchesMuscle(Exercise exercise, String muscle) {
    if (muscle == allOption) return true;
    const categories = <String, String>{
      'Pecho': 'mg_chest',
      'Espalda': 'mg_back',
      'Piernas': 'mg_lower_body',
      'Hombros': 'mg_shoulders',
      'Brazos': 'mg_arms',
      'Core': 'mg_core',
    };
    final profile = CuratedExerciseCatalog.anatomyFor(exercise.id);
    if (profile != null) {
      final targetId = categories[muscle];
      if (targetId != null) {
        return [
          profile.primaryId,
          ...profile.secondaryIds,
          ...profile.emphasisIds,
        ].any((id) => MuscleTaxonomyV1.belongsToGroup(id, targetId));
      }
      final node = MuscleTaxonomyV1.resolveLegacy(muscle).nodeId;
      if (node != null) {
        return [
          profile.primaryId, ...profile.secondaryIds, ...profile.emphasisIds,
        ].any((id) => id == node);
      }
    }
    final value = _normalize(exercise.muscleGroup);
    switch (muscle) {
      case 'Pecho':
        return value.contains('pecho') || value.contains('pectoral');
      case 'Espalda':
        return value.contains('espalda') ||
            value.contains('dorsal') ||
            value.contains('lumbar');
      case 'Piernas':
        return value.contains('pierna') ||
            value.contains('cuadriceps') ||
            value.contains('isquio') ||
            value.contains('gluteo') ||
            value.contains('gemelo') ||
            value.contains('pantorrilla');
      case 'Hombros':
        return value.contains('hombro') || value.contains('deltoide');
      case 'Brazos':
        return value.contains('brazo') ||
            value.contains('biceps') ||
            value.contains('triceps') ||
            value.contains('antebrazo');
      case 'Core':
        return value.contains('core') ||
            value.contains('abdomen') ||
            value.contains('abdominal');
      default:
        return value == _normalize(muscle);
    }
  }

  static List<Exercise> apply({
    required Iterable<Exercise> exercises,
    String query = '',
    String muscle = allOption,
    String? anatomyId,
    String equipment = allOption,
    ExerciseLateralityFilter laterality = ExerciseLateralityFilter.all,
    Set<String> favoriteIds = const <String>{},
    bool favoritesOnly = false,
  }) {
    final normalizedQuery = _normalize(query.trim());
    final normalizedEquipment = _normalize(equipment);

    return exercises.where((exercise) {
      final definition = CuratedExerciseCatalog.byId[exercise.id];
      final profile = CuratedExerciseCatalog.anatomyFor(exercise.id);
      final anatomyNames = profile == null
          ? ''
          : [profile.primaryId, ...profile.emphasisIds, ...profile.secondaryIds]
              .map((id) => MuscleTaxonomyV1.byId[id]?.labelEs ?? '')
              .join(' ');
      final searchable = _normalize(
        '${exercise.name} ${exercise.muscleGroup} ${exercise.equipment} '
        '${definition?.aliases.join(' ') ?? ''} '
        '${definition?.movementPattern ?? ''} $anatomyNames',
      );
      final matchesQuery =
          normalizedQuery.isEmpty || searchable.contains(normalizedQuery);
      final matchesEquipment = equipment == allOption ||
          _normalize(exercise.equipment) == normalizedEquipment;
      final unilateral = isUnilateral(exercise);
      final matchesLaterality = switch (laterality) {
        ExerciseLateralityFilter.all => true,
        ExerciseLateralityFilter.unilateral => unilateral,
        ExerciseLateralityFilter.bilateral => !unilateral,
      };
      final matchesFavorite =
          !favoritesOnly || favoriteIds.contains(exercise.id);

      return matchesQuery &&
          matchesMuscle(exercise, muscle) &&
          (anatomyId == null ||
              MuscleHierarchyBrowser.matchesExercise(exercise, anatomyId)) &&
          matchesEquipment &&
          matchesLaterality &&
          matchesFavorite;
    }).toList(growable: false);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}
