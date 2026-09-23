import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validDraft = CustomExerciseDraft(
    name: ' Remo unilateral casero ',
    muscleGroup: ' Espalda ',
    secondaryMuscles: [' Bíceps ', 'Bíceps', ''],
    equipment: ' Mancuerna ',
    instructions: '  Controla el recorrido.  ',
  );

  test('classifies preset and custom exercises without schema changes', () {
    expect(CustomExerciseService.isCustom(presetExercises.first), false);
    expect(
      CustomExerciseService.isCustom(
        Exercise(id: 'legacy_custom', name: 'Custom', muscleGroup: 'Core'),
      ),
      true,
    );
  });

  test('validates required fields and duplicate names case-insensitively', () {
    expect(
      CustomExerciseService.validateDraft(
        const CustomExerciseDraft(name: ' ', muscleGroup: 'Espalda'),
      ),
      isNotNull,
    );
    expect(
      CustomExerciseService.validateDraft(
        const CustomExerciseDraft(name: 'Nuevo', muscleGroup: ' '),
      ),
      isNotNull,
    );
    expect(
      CustomExerciseService.validateDraft(
        const CustomExerciseDraft(name: ' press banca ', muscleGroup: 'Pecho'),
        existingExercises: [
          Exercise(id: 'x', name: 'Press Banca', muscleGroup: 'Pecho'),
        ],
      ),
      isNotNull,
    );
  });

  test('normalizes a custom exercise deterministically', () {
    final exercise = CustomExerciseService.create(
      id: 'custom_test',
      draft: validDraft,
    );

    expect(exercise.id, 'custom_test');
    expect(exercise.name, 'Remo unilateral casero');
    expect(exercise.muscleGroup, 'Espalda');
    expect(exercise.secondaryMuscles, ['Bíceps']);
    expect(exercise.equipment, 'Mancuerna');
    expect(exercise.instructions, 'Controla el recorrido.');
  });

  test('editing preserves id and preset exercises cannot be overwritten', () {
    final original = Exercise(
      id: 'custom_keep_id',
      name: 'Nombre viejo',
      muscleGroup: 'Espalda',
    );
    final updated = CustomExerciseService.update(
      original: original,
      draft: const CustomExerciseDraft(
        name: 'Nombre nuevo',
        muscleGroup: 'Espalda',
      ),
    );

    expect(updated.id, original.id);
    expect(updated.name, 'Nombre nuevo');
    expect(
      () => CustomExerciseService.update(
        original: presetExercises.first,
        draft: validDraft,
      ),
      throwsStateError,
    );
  });

  test('detects routine references before deletion', () {
    final routine = Routine(
      id: 'r1',
      name: 'Rutina',
      scheduledDays: const [1],
      exercises: const [
        RoutineExercise(
          exerciseId: 'custom_used',
          order: 0,
          targetSets: 3,
          targetRepsMin: 8,
          targetRepsMax: 12,
          restSeconds: 90,
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
    );

    expect(
      CustomExerciseService.isReferencedByRoutine('custom_used', [routine]),
      true,
    );
    expect(
      CustomExerciseService.isReferencedByRoutine('custom_free', [routine]),
      false,
    );
  });
}
