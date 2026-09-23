import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<Exercise?> showCustomExerciseDialogWeb(
  BuildContext context,
  WidgetRef ref, {
  Exercise? exercise,
}) async {
  final name = TextEditingController(text: exercise?.name ?? '');
  final muscle = TextEditingController(text: exercise?.muscleGroup ?? '');
  final secondary = TextEditingController(
    text: exercise?.secondaryMuscles.join(', ') ?? '',
  );
  final equipment = TextEditingController(text: exercise?.equipment ?? '');
  final instructions = TextEditingController(text: exercise?.instructions ?? '');
  final formKey = GlobalKey<FormState>();

  try {
    return await showDialog<Exercise?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(exercise == null ? 'Nuevo ejercicio' : 'Editar ejercicio'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Escribe un nombre válido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: muscle,
                    decoration: const InputDecoration(labelText: 'Grupo muscular *'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Indica el grupo muscular'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: secondary,
                    decoration: const InputDecoration(
                      labelText: 'Músculos secundarios',
                      hintText: 'Bíceps, antebrazo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: equipment,
                    decoration: const InputDecoration(labelText: 'Equipo'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: instructions,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Instrucciones / técnica',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (exercise != null)
            TextButton.icon(
              onPressed: () async {
                final routines = ref.read(routineListProvider);
                if (CustomExerciseService.isReferencedByRoutine(
                  exercise.id,
                  routines,
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Está usado en una rutina. Quítalo de la rutina antes de borrarlo.',
                      ),
                    ),
                  );
                  return;
                }
                final deleted = await ref
                    .read(exerciseListProvider.notifier)
                    .deleteCustomExercise(exercise, routines: routines);
                if (deleted && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(null);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final draft = CustomExerciseDraft(
                name: name.text,
                muscleGroup: muscle.text,
                secondaryMuscles: secondary.text.split(','),
                equipment: equipment.text,
                instructions: instructions.text,
              );
              final error = CustomExerciseService.validateDraft(
                draft,
                existingExercises: ref.read(exerciseListProvider),
                editingExerciseId: exercise?.id,
              );
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }
              final notifier = ref.read(exerciseListProvider.notifier);
              final saved = exercise == null
                  ? await notifier.createCustomExercise(draft)
                  : await notifier.updateCustomExercise(exercise, draft);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(saved);
              }
            },
            child: Text(exercise == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  } finally {
    name.dispose();
    muscle.dispose();
    secondary.dispose();
    equipment.dispose();
    instructions.dispose();
  }
}
