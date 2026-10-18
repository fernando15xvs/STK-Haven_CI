import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/exercises/application/muscle_hierarchy_browser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves all 49 historical exercise IDs while reaching 180–250', () {
    expect(CuratedExerciseCatalog.entries, hasLength(180));
    expect(CuratedExerciseCatalog.legacyProfiles.keys, hasLength(49));
    expect(presetExercises, hasLength(229));
    final ids = presetExercises.map((exercise) => exercise.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      presetExercises.where((exercise) => exercise.id.startsWith('ex_')).length,
      49,
    );
    expect(
      presetExercises.where((exercise) => exercise.id.startsWith('exv2_'))
          .length,
      180,
    );
    for (final legacyId in CuratedExerciseCatalog.legacyProfiles.keys) {
      expect(ids, contains(legacyId), reason: legacyId);
    }
  });

  test('every preset has stable anatomy and nonempty safe technique', () {
    for (final exercise in presetExercises) {
      final profile = CuratedExerciseCatalog.anatomyFor(exercise.id);
      expect(profile, isNotNull, reason: exercise.id);
      expect(MuscleTaxonomyV1.byId.containsKey(profile!.primaryId), true,
          reason: exercise.id);
      for (final id in [...profile.secondaryIds, ...profile.emphasisIds]) {
        expect(MuscleTaxonomyV1.byId.containsKey(id), true,
            reason: '${exercise.id}: $id');
      }
      for (final id in profile.emphasisIds) {
        expect(MuscleTaxonomyV1.byId[id]!.isRegionalEmphasis, true,
            reason: '${exercise.id}: $id');
      }
      expect(exercise.name.trim(), isNotEmpty, reason: exercise.id);
      expect(exercise.equipment.trim(), isNotEmpty, reason: exercise.id);
      expect(exercise.instructions.trim(), isNotEmpty, reason: exercise.id);
      // Never advertise placeholder GIF/video assets as actual demonstrations.
      expect(exercise.media, isEmpty, reason: exercise.id);
    }
  });

  test('new variants have unique equipment-aware names and complete data', () {
    final names = <String>{};
    for (final def in CuratedExerciseCatalog.entries) {
      final semanticName = MuscleTaxonomyV1.normalize(def.name);
      expect(names.add(semanticName), true, reason: def.id);
      expect(def.movementPattern.trim(), isNotEmpty);
      expect(def.difficulty.trim(), isNotEmpty);
      expect(def.technique.trim(), isNotEmpty);
      expect(def.commonMistake.trim(), isNotEmpty);
      expect(def.anatomy.reviewed, isTrue);
      expect(def.toExercise().id, def.id);
      expect(CuratedExerciseCatalog.byId[def.id], same(def));
    }
  });

  test('specific regional emphasis is navigable without double counting', () {
    final upper = presetExercises.firstWhere(
        (exercise) => exercise.id == 'exv2_incline_barbell_press');
    final flat = presetExercises.firstWhere(
        (exercise) => exercise.id == 'ex_bench_press');
    final lateral = presetExercises.firstWhere(
        (exercise) => exercise.id == 'ex_lateral_raises');
    final rear = presetExercises.firstWhere(
        (exercise) => exercise.id == 'exv2_single_arm_rear_cable_fly');

    expect(MuscleHierarchyBrowser.matchesExercise(
        upper, 'reg_pec_clavicular'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        upper, 'reg_pec_inferior'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        upper, 'mg_chest'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        flat, 'reg_pec_esternocostal'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        lateral, 'reg_deltoid_lateral'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        lateral, 'reg_deltoid_anterior'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        rear, 'reg_deltoid_posterior'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        rear, 'mg_shoulders'), true);
  });

  test('obliques, serratus, rhomboids, calves and tibialis are represented', () {
    const targets = [
      'reg_pec_clavicular', 'reg_pec_esternocostal', 'reg_pec_inferior',
      'reg_deltoid_anterior', 'reg_deltoid_lateral',
      'reg_deltoid_posterior', 'mg_rhomboids', 'mg_hamstrings',
      'm_gluteus_medius', 'm_soleus', 'm_tibialis_anterior',
      'mg_obliques', 'm_serratus_anterior', 'mg_adductors',
      'm_iliopsoas',
    ];
    for (final id in targets) {
      final hits = presetExercises.where(
        (exercise) => MuscleHierarchyBrowser.matchesExercise(exercise, id),
      );
      expect(hits, isNotEmpty, reason: id);
    }
  });

  test('combined filters, aliases and unilateral metadata work offline', () {
    List<String> names(String query) => ExerciseLibraryFilter.apply(
      exercises: presetExercises, query: query,
    ).map((e) => e.name).toList();
    expect(names('pecho superior'), isNotEmpty);
    expect(names('deltoide posterior'), isNotEmpty);
    expect(names('isquiotibiales'), isNotEmpty);
    expect(names('oblicuos'), isNotEmpty);
    expect(names('romboides'), isNotEmpty);
    expect(names('serrato'), isNotEmpty);
    final single = ExerciseLibraryFilter.apply(
      exercises: presetExercises,
      anatomyId: 'reg_deltoid_posterior',
      equipment: 'Polea',
      laterality: ExerciseLateralityFilter.unilateral,
      query: 'posterior',
    );
    expect(single.map((exercise) => exercise.id),
        contains('exv2_single_arm_rear_cable_fly'));
    expect(single.every((e) => ExerciseLibraryFilter.isUnilateral(e)), true);
    expect(ExerciseLibraryFilter.apply(
        exercises: presetExercises, muscle: 'Core'), isNotEmpty);
    expect(ExerciseLibraryFilter.apply(
        exercises: presetExercises, muscle: 'Espalda'), isNotEmpty);
    expect(ExerciseLibraryFilter.apply(
        exercises: presetExercises, muscle: 'Piernas'), isNotEmpty);
  });

  test('repeated offline filtering scales without modifying historical IDs', () {
    final ids = presetExercises.map((exercise) => exercise.id).toList();
    for (var i = 0; i < 40; i++) {
      ExerciseLibraryFilter.apply(
        exercises: presetExercises,
        anatomyId: i.isEven ? 'mg_chest' : 'mg_lower_body',
        query: i.isEven ? 'press' : '',
      );
    }
    expect(presetExercises.map((exercise) => exercise.id).toList(), ids);
  });

  test('technical facets are complete and levels have actual alternatives', () {
    final categories = <ExerciseMovementCategory>{};
    final types = <ExerciseMechanics>{};
    final levels = <String>{};
    for (final entry in CuratedExerciseCatalog.entries) {
      categories.add(entry.movementCategory);
      types.add(entry.mechanics);
      levels.add(entry.difficulty);
      expect(entry.movementCategory.labelEs.trim(), isNotEmpty);
      expect(entry.mechanics.labelEs.trim(), isNotEmpty);
    }
    expect(categories.toSet(), ExerciseMovementCategory.values.toSet());
    expect(types.toSet(), ExerciseMechanics.values.toSet());
    expect(levels, {'Principiante', 'Intermedio', 'Avanzado'});
    expect(CuratedExerciseCatalog.byId['exv2_flat_machine_press']!.difficulty,
        'Principiante');
    expect(CuratedExerciseCatalog.byId['exv2_front_squat']!.difficulty,
        'Intermedio');
    expect(CuratedExerciseCatalog.byId['exv2_nordic_curl']!.difficulty,
        'Avanzado');
  });

  test('advanced facets combine safely with muscle/equipment and favorites', () {
    final all = presetExercises;
    final presses = ExerciseLibraryFilter.apply(
      exercises: all,
      movementCategory: ExerciseMovementCategory.horizontalPush,
      mechanics: ExerciseMechanics.compound,
      difficulty: 'Principiante',
      equipment: 'Máquina',
    );
    expect(presses.map((e) => e.id),
        contains('exv2_flat_machine_press'));
    expect(presses.every(
        (e) => CuratedExerciseCatalog.byId[e.id]!.difficulty == 'Principiante'),
        true);

    final shoulders = ExerciseLibraryFilter.apply(
      exercises: all,
      anatomyId: 'reg_deltoid_lateral',
      movementCategory: ExerciseMovementCategory.shoulder,
      mechanics: ExerciseMechanics.isolation,
      equipment: 'Mancuernas',
    );
    expect(shoulders.map((e) => e.id),
        contains('exv2_seated_db_lateral_raise'));
    // Historical records aren't assigned fabricated difficulty or mechanics.
    expect(shoulders.map((e) => e.id), isNot(contains('ex_lateral_raises')));

    final stable = ExerciseLibraryFilter.apply(
      exercises: all,
      movementCategory: ExerciseMovementCategory.core,
      mechanics: ExerciseMechanics.stability,
      bodyweightOnly: true,
      favoritesOnly: true,
      favoriteIds: {'exv2_high_plank', 'exv2_flat_machine_press'},
    );
    expect(stable.map((e) => e.id).toList(), ['exv2_high_plank']);

    final old = all.firstWhere((e) => e.id == 'ex_bench_press');
    expect(ExerciseLibraryFilter.apply(
      exercises: [old],
      movementCategory: ExerciseMovementCategory.horizontalPush,
    ), isEmpty);
    expect(ExerciseLibraryFilter.apply(exercises: [old]), hasLength(1));
  });

  test('faceted offline filtering is repeatable without data writes', () {
    final ids = [for (final e in presetExercises) e.id];
    for (var i = 0; i < 180; i++) {
      final hits = ExerciseLibraryFilter.apply(
        exercises: presetExercises,
        movementCategory: ExerciseMovementCategory.values[
            i % ExerciseMovementCategory.values.length],
        mechanics: ExerciseMechanics.values[
            i % ExerciseMechanics.values.length],
        difficulty: const ['Principiante', 'Intermedio', 'Avanzado'][i % 3],
        bodyweightOnly: i.isEven,
      );
      expect(hits.every((e) => CuratedExerciseCatalog.byId[e.id] != null),
          true);
    }
    expect([for (final e in presetExercises) e.id], ids);
  });
}
