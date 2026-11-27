import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/features/exercises/application/muscle_hierarchy_browser.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:core/domain/models/workout_session.dart';

enum ExerciseLateralityFilter { all, unilateral, bilateral, unspecified }
enum ExerciseLibrarySort { relevance, alphabetical, recent, mostUsed }
enum ExerciseLibraryFacet {
  equipment, laterality, anatomy, movement, mechanics, difficulty,
  bodyweight, custom, secondary,
}

class AdvancedExerciseFilterSelection {
  final String equipment;
  final ExerciseLateralityFilter laterality;
  final String? anatomyId;
  final ExerciseMovementCategory? movementCategory;
  final ExerciseMechanics? mechanics;
  final String difficulty;
  final bool bodyweightOnly;
  final bool customOnly;
  final bool includeSecondary;

  const AdvancedExerciseFilterSelection({
    this.equipment = ExerciseLibraryFilter.allOption,
    this.laterality = ExerciseLateralityFilter.all,
    this.anatomyId,
    this.movementCategory,
    this.mechanics,
    this.difficulty = ExerciseLibraryFilter.allOption,
    this.bodyweightOnly = false,
    this.customOnly = false,
    this.includeSecondary = false,
  });

  List<ExerciseLibraryFacet> get activeFacets => [
    if (equipment != ExerciseLibraryFilter.allOption) ExerciseLibraryFacet.equipment,
    if (laterality != ExerciseLateralityFilter.all) ExerciseLibraryFacet.laterality,
    if (anatomyId != null) ExerciseLibraryFacet.anatomy,
    if (movementCategory != null) ExerciseLibraryFacet.movement,
    if (mechanics != null) ExerciseLibraryFacet.mechanics,
    if (difficulty != ExerciseLibraryFilter.allOption) ExerciseLibraryFacet.difficulty,
    if (bodyweightOnly) ExerciseLibraryFacet.bodyweight,
    if (customOnly) ExerciseLibraryFacet.custom,
    if (includeSecondary) ExerciseLibraryFacet.secondary,
  ];
  int get activeCount => activeFacets.length;

  AdvancedExerciseFilterSelection without(ExerciseLibraryFacet facet) =>
      AdvancedExerciseFilterSelection(
        equipment: facet == ExerciseLibraryFacet.equipment ? ExerciseLibraryFilter.allOption : equipment,
        laterality: facet == ExerciseLibraryFacet.laterality ? ExerciseLateralityFilter.all : laterality,
        anatomyId: facet == ExerciseLibraryFacet.anatomy ? null : anatomyId,
        movementCategory: facet == ExerciseLibraryFacet.movement ? null : movementCategory,
        mechanics: facet == ExerciseLibraryFacet.mechanics ? null : mechanics,
        difficulty: facet == ExerciseLibraryFacet.difficulty ? ExerciseLibraryFilter.allOption : difficulty,
        bodyweightOnly: facet != ExerciseLibraryFacet.bodyweight && bodyweightOnly,
        customOnly: facet != ExerciseLibraryFacet.custom && customOnly,
        includeSecondary: facet != ExerciseLibraryFacet.secondary && includeSecondary,
      );
}

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

  static bool isUnilateral(Exercise exercise) =>
      lateralityOf(exercise) == ExerciseLateralityFilter.unilateral;

  static ExerciseLateralityFilter lateralityOf(Exercise exercise) {
    final definition = CuratedExerciseCatalog.byId[exercise.id];
    if (definition != null) {
      return definition.unilateral
          ? ExerciseLateralityFilter.unilateral
          : ExerciseLateralityFilter.bilateral;
    }
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
    if (markers.any(text.contains)) return ExerciseLateralityFilter.unilateral;
    if (RegExp(r'\bbilateral\b|\bambos brazos\b|\bambas piernas\b|\bdos brazos\b|\bdos piernas\b').hasMatch(text)) {
      return ExerciseLateralityFilter.bilateral;
    }
    return ExerciseLateralityFilter.unspecified;
  }

  static bool matchesMuscle(Exercise exercise, String muscle, {bool includeSecondary = true}) {
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
          if (includeSecondary) ...profile.secondaryIds,
          ...profile.emphasisIds,
        ].any((id) => MuscleTaxonomyV1.belongsToGroup(id, targetId));
      }
      final node = MuscleTaxonomyV1.resolveLegacy(muscle).nodeId;
      if (node != null) {
        return [
          profile.primaryId, if (includeSecondary) ...profile.secondaryIds, ...profile.emphasisIds,
        ].any((id) => id == node);
      }
    }
    final value = _normalize([exercise.muscleGroup, if (includeSecondary) ...exercise.secondaryMuscles].join(' '));
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
        return [exercise.muscleGroup, if (includeSecondary) ...exercise.secondaryMuscles]
            .any((label) => _normalize(label) == _normalize(muscle));
    }
  }

  static List<Exercise> apply({
    required Iterable<Exercise> exercises,
    String query = '',
    String muscle = allOption,
    String? anatomyId,
    String equipment = allOption,
    ExerciseLateralityFilter laterality = ExerciseLateralityFilter.all,
    ExerciseMovementCategory? movementCategory,
    ExerciseMechanics? mechanics,
    String difficulty = allOption,
    bool bodyweightOnly = false,
    Set<String> favoriteIds = const <String>{},
    bool favoritesOnly = false,
    bool customOnly = false,
    bool includeSecondary = true,
    ExerciseLibrarySort sort = ExerciseLibrarySort.relevance,
    WorkoutHistoryIndex? historyIndex,
  }) {
    final normalizedQuery = _normalize(query.trim());
    final normalizedEquipment = _normalize(equipment);

    final scores = <String, int>{};
    final result = exercises.where((exercise) {
      final definition = CuratedExerciseCatalog.byId[exercise.id];
      final score = normalizedQuery.isEmpty ? 0
          : _searchScore(normalizedQuery, exercise.name, _searchable(exercise));
      scores[exercise.id] = score;
      final matchesQuery = score >= 0;
      final matchesEquipment = equipment == allOption ||
          _normalize(exercise.equipment) == normalizedEquipment;
      final matchesLaterality = laterality == ExerciseLateralityFilter.all ||
          lateralityOf(exercise) == laterality;
      final matchesFavorite =
          !favoritesOnly || favoriteIds.contains(exercise.id);
      // No guessing facets for old presets or personal exercises. They remain
      // present in the unfiltered library; specific advanced facets require
      // curated per-exercise metadata.
      final matchesPattern =
          movementCategory == null || definition?.movementCategory == movementCategory;
      final matchesMechanics =
          mechanics == null || definition?.mechanics == mechanics;
      final matchesDifficulty = difficulty == allOption ||
          definition?.difficulty == difficulty;
      final matchesBodyweight = !bodyweightOnly ||
          _normalize(exercise.equipment) == _normalize('Peso corporal');

      return (!customOnly || CustomExerciseService.isCustom(exercise)) &&
          matchesPattern &&
          matchesMechanics &&
          matchesDifficulty &&
          matchesBodyweight &&
          matchesQuery &&
          matchesMuscle(exercise, muscle, includeSecondary: includeSecondary) &&
          (anatomyId == null ||
              MuscleHierarchyBrowser.matchesExercise(exercise, anatomyId, includeSecondary: includeSecondary)) &&
          matchesEquipment &&
          matchesLaterality &&
          matchesFavorite;
    }).toList();
    if (sort == ExerciseLibrarySort.relevance && normalizedQuery.isEmpty && muscle == allOption) {
      return result;
    }
    final counts = <String, int>{};
    final latest = <String, DateTime>{};
    if (historyIndex != null && (sort == ExerciseLibrarySort.recent || sort == ExerciseLibrarySort.mostUsed)) {
      for (final exercise in result) {
        final occurrences = historyIndex.exerciseOccurrences(exercise.id)
            .where((occurrence) => occurrence.exercise.sets.any(
                (set) => set.completed && set.setType == WorkoutSetType.working))
            .toList();
        counts[exercise.id] = occurrences.map((e) => e.session.id).toSet().length;
        if (occurrences.isNotEmpty) latest[exercise.id] = occurrences.first.date;
      }
    }
    final originalOrder = {for (var i = 0; i < result.length; i++) result[i].id: i};
    result.sort((a, b) {
      int comparison;
      switch (sort) {
        case ExerciseLibrarySort.relevance:
          comparison = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
          if (comparison == 0 && muscle != allOption) {
            comparison = (matchesMuscle(b, muscle, includeSecondary: false) ? 1 : 0)
                .compareTo(matchesMuscle(a, muscle, includeSecondary: false) ? 1 : 0);
          }
          break;
        case ExerciseLibrarySort.alphabetical:
          comparison = _normalize(a.name).compareTo(_normalize(b.name));
          break;
        case ExerciseLibrarySort.recent:
          final aDate = latest[a.id];
          final bDate = latest[b.id];
          comparison = aDate == null ? (bDate == null ? 0 : 1)
              : bDate == null ? -1 : bDate.compareTo(aDate);
          break;
        case ExerciseLibrarySort.mostUsed:
          comparison = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
          break;
      }
      if (comparison != 0) return comparison;
      return originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
    });
    return result;
  }

  static final _searchText = Expando<String>('exercise library search');

  static String _searchable(Exercise exercise) {
    final cached = _searchText[exercise];
    if (cached != null) return cached;
    final definition = CuratedExerciseCatalog.byId[exercise.id];
      final profile = CuratedExerciseCatalog.anatomyFor(exercise.id);
      final anatomyNames = profile == null
          ? ''
          : [profile.primaryId, ...profile.emphasisIds, ...profile.secondaryIds]
              .map((id) {
                final node = MuscleTaxonomyV1.byId[id];
                return node == null
                    ? ''
                    : [node.labelEs, node.anatomicalName, ...node.aliases]
                        .join(' ');
              }).join(' ');
      return _searchText[exercise] = _normalize(
        '${exercise.name} ${exercise.muscleGroup} ${exercise.secondaryMuscles.join(' ')} ${exercise.equipment} '
        '${definition?.aliases.join(' ') ?? ''} '
        '${definition?.movementPattern ?? ''} $anatomyNames',
      );
  }

  static int _searchScore(String query, String name, String searchable) {
    if (query.isEmpty) return 0;
    final normalizedName = _normalize(name);
    if (normalizedName == query) return 10000;
    final tokens = query.split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
    final nameWords = normalizedName.split(RegExp(r'[^a-z0-9]+'));
    final words = searchable.split(RegExp(r'[^a-z0-9]+'));
    var score = 0;
    for (final token in tokens) {
      if (nameWords.contains(token)) {
        score += 30;
      } else if (normalizedName.contains(token)) {
        score += 20;
      } else if (searchable.contains(token)) {
        score += 10;
      } else if (token.length >= 5 && words.any((word) => _oneEdit(token, word))) {
        score += 1;
      } else {
        return -1;
      }
    }
    return score;
  }

  static bool _oneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else {
        if (++edits > 1) return false;
        if (a.length >= b.length) i++;
        if (b.length >= a.length) j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
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
