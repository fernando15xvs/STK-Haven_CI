import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:core/features/exercises/application/muscle_hierarchy_browser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hierarchy walks from groups down to specific regions', () {
    expect(
      MuscleHierarchyBrowser.childrenOf(null).map((node) => node.id),
      containsAll(['mg_upper_body', 'mg_lower_body', 'mg_core']),
    );
    expect(
      MuscleHierarchyBrowser.pathTo('m_semitendinosus').map((n) => n.id),
      ['mg_lower_body', 'mg_thighs', 'mg_hamstrings', 'm_semitendinosus'],
    );
    expect(
      MuscleHierarchyBrowser.pathTo('reg_deltoid_posterior').last.labelEs,
      'Deltoides posterior',
    );
    expect(
      MuscleHierarchyBrowser.childrenOf('mg_core')
          .where((node) => node.id == 'm_serratus_anterior')
          .length,
      1,
    );
    expect(MuscleHierarchyBrowser.childrenOf('unknown'), isEmpty);
    expect(MuscleHierarchyBrowser.pathTo('unknown'), isEmpty);
  });

  test('unknown or broad labels never become specific muscle matches', () {
    final broad = Exercise(
      id: 'legacy_shoulder', name: 'Press militar',
      muscleGroup: 'Hombros',
    );
    final detailed = Exercise(
      id: 'rear', name: 'Pájaro',
      muscleGroup: 'Hombro posterior',
    );
    expect(MuscleHierarchyBrowser.matchesExercise(broad, 'mg_shoulders'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        broad, 'reg_deltoid_anterior'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        broad, 'reg_deltoid_posterior'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        detailed, 'reg_deltoid_posterior'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        detailed, 'mg_shoulders'), true);
    expect(MuscleHierarchyBrowser.matchesExercise(
        detailed, 'm_deltoid'), false);
  });

  test('anatomical filter combines with existing search, equipment and favorites', () {
    final exercises = [
      Exercise(id: 'broad', name: 'Press banca', muscleGroup: 'Pecho',
          equipment: 'Barra'),
      Exercise(id: 'upper', name: 'Press inclinado', muscleGroup: 'Pecho superior',
          equipment: 'Mancuernas'),
      Exercise(id: 'oblique', name: 'Rotación', muscleGroup: 'Oblicuo externo'),
      Exercise(id: 'serratus', name: 'Empuje escapular',
          muscleGroup: 'Serrato anterior'),
      Exercise(id: 'combined', name: 'Puente',
          muscleGroup: 'Glúteos e isquios'),
      Exercise(id: 'unknown', name: 'Otro', muscleGroup: '???'),
    ];
    expect(
      ExerciseLibraryFilter.apply(exercises: exercises, anatomyId: 'mg_chest')
          .map((e) => e.id),
      ['broad', 'upper'],
    );
    expect(
      ExerciseLibraryFilter.apply(
        exercises: exercises, anatomyId: 'reg_pec_clavicular',
        equipment: 'Mancuernas', query: 'inclinado',
        favoriteIds: {'upper'}, favoritesOnly: true,
      ).map((e) => e.id),
      ['upper'],
    );
    expect(
      ExerciseLibraryFilter.apply(
          exercises: exercises, anatomyId: 'reg_pec_clavicular',
          equipment: 'Barra'),
      isEmpty,
    );
    expect(MuscleHierarchyBrowser.matchesExercise(
        exercises[3], 'mg_core'), true); // Cross-listing without new node.
    expect(MuscleHierarchyBrowser.matchesExercise(
        exercises[4], 'm_gluteus_maximus'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        exercises[5], 'mg_lower_body'), false);
    expect(MuscleHierarchyBrowser.matchesExercise(
        exercises[0], 'invalid'), false);
    expect(MuscleTaxonomyV1.byId['reg_pec_clavicular']!.isCategory, false);
  });

  test('hierarchy and filtering do not mutate exercise fields', () {
    final exercise = Exercise(
      id: 'old', name: 'Ejercicio antiguo',
      muscleGroup: 'Hombros',
      secondaryMuscles: const ['Tríceps y hombro'],
    );
    final before = (exercise.id, exercise.name, exercise.muscleGroup,
        [...exercise.secondaryMuscles]);
    MuscleHierarchyBrowser.childrenOf('mg_shoulders');
    MuscleHierarchyBrowser.matchesExercise(exercise, 'mg_shoulders');
    MuscleHierarchyBrowser.matchesExercise(exercise, 'reg_deltoid_lateral');
    final after = (exercise.id, exercise.name, exercise.muscleGroup,
        [...exercise.secondaryMuscles]);
    expect(after.toString(), before.toString());
  });
}
