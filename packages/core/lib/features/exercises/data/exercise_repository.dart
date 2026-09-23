import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/database/hive/models/hive_exercise.dart';

class ExerciseRepository {
  final Box<HiveExercise> _box;

  ExerciseRepository(this._box);

  Future<void> addExercise(Exercise exercise) async {
    await _box.put(exercise.id, _toHive(exercise));
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _box.put(exercise.id, _toHive(exercise));
  }

  Future<void> deleteExercise(String id) async {
    await _box.delete(id);
  }

  List<Exercise> getAllExercises() {
    return _box.values.map(_fromHive).toList();
  }

  Exercise? getExerciseById(String id) {
    final h = _box.get(id);
    return h == null ? null : _fromHive(h);
  }

  HiveExercise _toHive(Exercise model) {
    return HiveExercise(
      id: model.id,
      name: model.name,
      muscleGroup: model.muscleGroup,
      secondaryMuscles: model.secondaryMuscles,
      equipment: model.equipment,
      instructions: model.instructions,
      media: model.media,
    );
  }

  Exercise _fromHive(HiveExercise h) {
    return Exercise(
      id: h.id,
      name: h.name,
      muscleGroup: h.muscleGroup,
      secondaryMuscles: h.secondaryMuscles,
      equipment: h.equipment,
      instructions: h.instructions,
      media: h.media,
    );
  }
}
