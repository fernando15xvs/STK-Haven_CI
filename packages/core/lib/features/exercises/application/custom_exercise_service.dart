import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';

class CustomExerciseDraft {
  final String name;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String equipment;
  final String instructions;
  final String media;

  const CustomExerciseDraft({
    required this.name,
    required this.muscleGroup,
    this.secondaryMuscles = const [],
    this.equipment = '',
    this.instructions = '',
    this.media = '',
  });
}

class CustomExerciseService {
  static final Set<String> _presetIds =
      presetExercises.map((exercise) => exercise.id).toSet();

  static bool isCustom(Exercise exercise) => !_presetIds.contains(exercise.id);

  static bool isPresetId(String exerciseId) => _presetIds.contains(exerciseId);

  static String? validateDraft(
    CustomExerciseDraft draft, {
    Iterable<Exercise> existingExercises = const [],
    String? editingExerciseId,
  }) {
    final name = _normalizeText(draft.name);
    final muscle = _normalizeText(draft.muscleGroup);

    if (name.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (muscle.isEmpty) return 'Selecciona o escribe un grupo muscular.';

    final duplicate = existingExercises.any((exercise) {
      if (exercise.id == editingExerciseId) return false;
      return _normalizeText(exercise.name).toLowerCase() == name.toLowerCase();
    });
    if (duplicate) return 'Ya existe un ejercicio con ese nombre.';

    return null;
  }

  static Exercise create({
    required String id,
    required CustomExerciseDraft draft,
  }) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'El id no puede estar vacío.');
    }
    if (isPresetId(cleanId)) {
      throw ArgumentError.value(id, 'id', 'El id pertenece al catálogo base.');
    }
    return Exercise(
      id: cleanId,
      name: _normalizeText(draft.name),
      muscleGroup: _normalizeText(draft.muscleGroup),
      secondaryMuscles: _normalizeList(draft.secondaryMuscles),
      equipment: _normalizeText(draft.equipment),
      instructions: draft.instructions.trim(),
      media: draft.media.trim(),
    );
  }

  static Exercise update({
    required Exercise original,
    required CustomExerciseDraft draft,
  }) {
    if (!isCustom(original)) {
      throw StateError('Los ejercicios predefinidos no se pueden sobrescribir.');
    }
    return Exercise(
      id: original.id,
      name: _normalizeText(draft.name),
      muscleGroup: _normalizeText(draft.muscleGroup),
      secondaryMuscles: _normalizeList(draft.secondaryMuscles),
      equipment: _normalizeText(draft.equipment),
      instructions: draft.instructions.trim(),
      media: draft.media.trim(),
    );
  }

  static bool isReferencedByRoutine(
    String exerciseId,
    Iterable<Routine> routines,
  ) {
    return routines.any(
      (routine) => routine.exercises.any(
        (exercise) => exercise.exerciseId == exerciseId,
      ),
    );
  }

  static String _normalizeText(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _normalizeList(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final clean = _normalizeText(value);
      if (clean.isEmpty) continue;
      final key = clean.toLowerCase();
      if (seen.add(key)) normalized.add(clean);
    }
    return normalized;
  }
}
