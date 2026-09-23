import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/exercise_library_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exercises = <Exercise>[
    Exercise(
      id: 'bench',
      name: 'Press de Banca',
      muscleGroup: 'Pecho',
      equipment: 'Barra',
    ),
    Exercise(
      id: 'row_uni',
      name: 'Remo Unilateral Máquina',
      muscleGroup: 'Espalda',
      equipment: 'Máquina',
      instructions: 'Tira con un solo brazo.',
    ),
    Exercise(
      id: 'curl_alt',
      name: 'Curl Alterno c/M',
      muscleGroup: 'Bíceps',
      equipment: 'Mancuernas',
    ),
    Exercise(
      id: 'pulldown',
      name: 'Jalón al Pecho',
      muscleGroup: 'Espalda',
      equipment: 'Polea',
    ),
  ];

  group('ExerciseLibraryFilter', () {
    test('builds deterministic equipment options', () {
      expect(
        ExerciseLibraryFilter.equipmentOptions(exercises),
        ['Todos', 'Barra', 'Mancuernas', 'Máquina', 'Polea'],
      );
    });

    test('filters by muscle and exact equipment', () {
      final result = ExerciseLibraryFilter.apply(
        exercises: exercises,
        muscle: 'Espalda',
        equipment: 'Polea',
      );

      expect(result.map((exercise) => exercise.id), ['pulldown']);
    });

    test('detects unilateral exercises from shared metadata rules', () {
      expect(ExerciseLibraryFilter.isUnilateral(exercises[1]), true);
      expect(ExerciseLibraryFilter.isUnilateral(exercises[2]), true);
      expect(ExerciseLibraryFilter.isUnilateral(exercises[0]), false);
    });

    test('filters unilateral and bilateral independently', () {
      final unilateral = ExerciseLibraryFilter.apply(
        exercises: exercises,
        laterality: ExerciseLateralityFilter.unilateral,
      );
      final bilateral = ExerciseLibraryFilter.apply(
        exercises: exercises,
        laterality: ExerciseLateralityFilter.bilateral,
      );

      expect(unilateral.map((exercise) => exercise.id), ['row_uni', 'curl_alt']);
      expect(bilateral.map((exercise) => exercise.id), ['bench', 'pulldown']);
    });

    test('combines favorites, search and filters', () {
      final result = ExerciseLibraryFilter.apply(
        exercises: exercises,
        query: 'remo',
        muscle: 'Espalda',
        equipment: 'Máquina',
        laterality: ExerciseLateralityFilter.unilateral,
        favoriteIds: {'row_uni'},
        favoritesOnly: true,
      );

      expect(result.map((exercise) => exercise.id), ['row_uni']);
    });
  });
}
