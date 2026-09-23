import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_exercise.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/data/exercise_repository.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/routine.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final box = Hive.box<HiveExercise>(HiveBoxes.exercises);
  return ExerciseRepository(box);
});

final exerciseListProvider =
    NotifierProvider<ExerciseListNotifier, List<Exercise>>(
  ExerciseListNotifier.new,
);

class ExerciseListNotifier extends Notifier<List<Exercise>> {
  @override
  List<Exercise> build() {
    final repo = ref.read(exerciseRepositoryProvider);
    final existingIds = repo.getAllExercises().map((e) => e.id).toSet();

    final needsSeed = presetExercises.any((p) => !existingIds.contains(p.id));

    if (needsSeed) {
      Future.microtask(ensureSeeded);
      final list = repo.getAllExercises().toList();
      for (final p in presetExercises) {
        if (!existingIds.contains(p.id)) list.add(p);
      }
      return list;
    }
    return repo.getAllExercises();
  }

  Future<void> addExercise(Exercise exercise) async {
    await ref.read(exerciseRepositoryProvider).addExercise(exercise);
    _refreshFromRepository();
  }

  Future<Exercise> createCustomExercise(CustomExerciseDraft draft) async {
    final error = CustomExerciseService.validateDraft(
      draft,
      existingExercises: state,
    );
    if (error != null) throw ArgumentError(error);

    final exercise = CustomExerciseService.create(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      draft: draft,
    );
    await ref.read(exerciseRepositoryProvider).addExercise(exercise);
    _refreshFromRepository();
    return exercise;
  }

  Future<Exercise> updateCustomExercise(
    Exercise original,
    CustomExerciseDraft draft,
  ) async {
    final error = CustomExerciseService.validateDraft(
      draft,
      existingExercises: state,
      editingExerciseId: original.id,
    );
    if (error != null) throw ArgumentError(error);

    final updated = CustomExerciseService.update(
      original: original,
      draft: draft,
    );
    await ref.read(exerciseRepositoryProvider).updateExercise(updated);
    _refreshFromRepository();
    return updated;
  }

  Future<bool> deleteCustomExercise(
    Exercise exercise, {
    Iterable<Routine> routines = const [],
  }) async {
    if (!CustomExerciseService.isCustom(exercise)) return false;
    if (CustomExerciseService.isReferencedByRoutine(exercise.id, routines)) {
      return false;
    }
    await ref.read(exerciseRepositoryProvider).deleteExercise(exercise.id);
    _refreshFromRepository();
    return true;
  }

  Future<void> ensureSeeded() async {
    final repo = ref.read(exerciseRepositoryProvider);
    final existingIds = repo.getAllExercises().map((e) => e.id).toSet();
    var updated = false;

    for (final preset in presetExercises) {
      if (!existingIds.contains(preset.id)) {
        await repo.addExercise(preset);
        updated = true;
      }
    }

    if (updated) _refreshFromRepository();
  }

  void _refreshFromRepository() {
    state = ref.read(exerciseRepositoryProvider).getAllExercises();
  }
}
