import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/application/custom_exercise_service.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class CustomExerciseEditorPage extends ConsumerStatefulWidget {
  final Exercise? exercise;

  const CustomExerciseEditorPage({super.key, this.exercise});

  @override
  ConsumerState<CustomExerciseEditorPage> createState() =>
      _CustomExerciseEditorPageState();
}

class _CustomExerciseEditorPageState
    extends ConsumerState<CustomExerciseEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _muscleController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _instructionsController;
  bool _saving = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _nameController = TextEditingController(text: exercise?.name ?? '');
    _muscleController = TextEditingController(text: exercise?.muscleGroup ?? '');
    _secondaryController = TextEditingController(
      text: exercise?.secondaryMuscles.join(', ') ?? '',
    );
    _equipmentController = TextEditingController(text: exercise?.equipment ?? '');
    _instructionsController =
        TextEditingController(text: exercise?.instructions ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    _secondaryController.dispose();
    _equipmentController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  CustomExerciseDraft _draft() => CustomExerciseDraft(
        name: _nameController.text,
        muscleGroup: _muscleController.text,
        secondaryMuscles: _secondaryController.text.split(','),
        equipment: _equipmentController.text,
        instructions: _instructionsController.text,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = CustomExerciseService.validateDraft(
      _draft(),
      existingExercises: ref.read(exerciseListProvider),
      editingExerciseId: widget.exercise?.id,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(exerciseListProvider.notifier);
      final saved = _isEditing
          ? await notifier.updateCustomExercise(widget.exercise!, _draft())
          : await notifier.createCustomExercise(_draft());
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final exercise = widget.exercise;
    if (exercise == null) return;
    final routines = ref.read(routineListProvider);
    if (CustomExerciseService.isReferencedByRoutine(exercise.id, routines)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este ejercicio está usado en una rutina. Quítalo de la rutina antes de borrarlo.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar “${exercise.name}” de tu biblioteca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await ref.read(exerciseListProvider.notifier).deleteCustomExercise(
          exercise,
          routines: routines,
        );
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop(null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el ejercicio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar ejercicio',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _isEditing
                    ? 'Actualiza tus datos sin perder el historial asociado.'
                    : 'Crea un ejercicio propio para usarlo en rutinas y entrenamientos.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Escribe un nombre válido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _muscleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Grupo muscular *',
                  hintText: 'Ej. Espalda',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Indica el grupo muscular'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _secondaryController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Músculos secundarios',
                  hintText: 'Ej. Bíceps, antebrazo',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _equipmentController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Equipo',
                  hintText: 'Ej. Mancuernas',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _instructionsController,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Instrucciones / técnica',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Guardar cambios' : 'Crear ejercicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
