import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_personal_settings_provider.dart';
import 'package:core/features/routines/application/routine_order_coordinator.dart';
import 'package:core/features/routines/application/routine_superset_coordinator.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';

import '../../../core/theme/app_colors.dart';
import 'exercise_picker_page_web.dart';

class CreateRoutinePageWeb extends ConsumerStatefulWidget {
  final Routine? editingRoutine;

  const CreateRoutinePageWeb({super.key, this.editingRoutine});

  @override
  ConsumerState<CreateRoutinePageWeb> createState() => _CreateRoutinePageWebState();
}

class _CreateRoutinePageWebState extends ConsumerState<CreateRoutinePageWeb> {
  final _nameController = TextEditingController();
  final List<RoutineExercise> _selectedExercises = [];
  final Set<int> _scheduledDays = <int>{};

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    final routine = widget.editingRoutine;
    if (routine != null) {
      _nameController.text = routine.name;
      _scheduledDays.addAll(routine.scheduledDays);
      _selectedExercises.addAll(
        RoutineOrderCoordinator.normalize(
          RoutineSupersetCoordinator.normalize(routine.exercises),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _replaceExercises(List<RoutineExercise> exercises) {
    final normalized = RoutineOrderCoordinator.normalize(
      List<RoutineExercise>.from(exercises),
    );
    _selectedExercises
      ..clear()
      ..addAll(normalized);
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      _replaceExercises(
        RoutineOrderCoordinator.move(
          _selectedExercises,
          oldIndex,
          newIndex,
        ),
      );
    });
  }

  Future<void> _pickExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerPageWeb()),
    );
    if (exercise == null || !mounted) return;
    await _configureExercise(exercise);
  }

  Future<void> _editExercise(int index, Exercise exercise) async {
    await _configureExercise(exercise, index: index);
  }

  Future<void> _configureExercise(Exercise exercise, {int? index}) async {
    final current = index == null ? null : _selectedExercises[index];
    final personal = ref
        .read(exercisePersonalSettingsProvider.notifier)
        .settingsFor(exercise.id);
    final notesController = TextEditingController(text: personal.technicalNotes);
    int sets = current?.targetSets ?? 3;
    int minReps = current?.targetRepsMin ?? 8;
    int maxReps = current?.targetRepsMax ?? 12;
    int rest = current?.restSeconds ?? 90;
    int warmupSets = current?.warmupSets ?? personal.warmupSets;
    int approachSets = current?.approachSets ?? personal.approachSets;
    bool unilateral = current?.unilateral ?? false;
    UnilateralTarget unilateralTarget =
        current?.unilateralTarget ?? UnilateralTarget.other;

    final result = await showDialog<RoutineExercise>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget counter(
            String label,
            int value,
            VoidCallback? minus,
            VoidCallback? plus,
          ) {
            return Row(
              children: [
                Expanded(child: Text(label)),
                IconButton.outlined(
                  onPressed: minus,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSmall,
                  ),
                ),
                IconButton.outlined(
                  onPressed: plus,
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name),
                const SizedBox(height: 4),
                Text(
                  'Configura este ejercicio sin afectar a los demás.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: 'Series efectivas',
                      child: Column(
                        children: [
                          counter(
                            'Series de trabajo',
                            sets,
                            sets > 1
                                ? () => setDialogState(() => sets--)
                                : null,
                            sets < 10
                                ? () => setDialogState(() => sets++)
                                : null,
                          ),
                          counter(
                            'Reps mínimas',
                            minReps,
                            minReps > 1
                                ? () => setDialogState(() => minReps--)
                                : null,
                            minReps < 50
                                ? () => setDialogState(() {
                                    minReps++;
                                    if (maxReps < minReps) maxReps = minReps;
                                  })
                                : null,
                          ),
                          counter(
                            'Reps máximas',
                            maxReps,
                            maxReps > minReps
                                ? () => setDialogState(() => maxReps--)
                                : null,
                            maxReps < 50
                                ? () => setDialogState(() => maxReps++)
                                : null,
                          ),
                          counter(
                            'Descanso (s)',
                            rest,
                            rest > 15
                                ? () => setDialogState(() => rest -= 15)
                                : null,
                            rest < 300
                                ? () => setDialogState(() => rest += 15)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Preparación predeterminada',
                      subtitle:
                          'Se recordará para la próxima vez que añadas este ejercicio. No cuenta como series efectivas ni para PRs.',
                      child: Column(
                        children: [
                          counter(
                            'Calentamiento',
                            warmupSets,
                            warmupSets > 0
                                ? () => setDialogState(() => warmupSets--)
                                : null,
                            warmupSets < 5
                                ? () => setDialogState(() => warmupSets++)
                                : null,
                          ),
                          counter(
                            'Aproximación',
                            approachSets,
                            approachSets > 0
                                ? () => setDialogState(() => approachSets--)
                                : null,
                            approachSets < 5
                                ? () => setDialogState(() => approachSets++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Nota técnica personal',
                      subtitle:
                          'Guarda recordatorios propios de ejecución para este ejercicio.',
                      child: TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 1200,
                        decoration: const InputDecoration(
                          hintText: 'Ej. mantener escápulas atrás, pausa abajo...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Trabajo unilateral',
                      subtitle:
                          'Actívalo cuando haces primero un lado y después el otro.',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Registrar izquierda y derecha'),
                            value: unilateral,
                            onChanged: (value) =>
                                setDialogState(() => unilateral = value),
                          ),
                          if (unilateral)
                            DropdownButtonFormField<UnilateralTarget>(
                              initialValue: unilateralTarget,
                              decoration: const InputDecoration(
                                labelText: 'Zona unilateral',
                              ),
                              items: UnilateralTarget.values
                                  .map(
                                    (target) => DropdownMenuItem(
                                      value: target,
                                      child: Text(target.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => unilateralTarget = value,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  RoutineExercise(
                    exerciseId: exercise.id,
                    order: index ?? _selectedExercises.length,
                    targetSets: sets,
                    targetRepsMin: minReps,
                    targetRepsMax: maxReps,
                    restSeconds: rest,
                    warmupSets: warmupSets,
                    approachSets: approachSets,
                    unilateral: unilateral,
                    unilateralTarget: unilateralTarget,
                    supersetGroupId: current?.supersetGroupId,
                  ),
                ),
                child: Text(index == null ? 'Añadir' : 'Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      await ref.read(exercisePersonalSettingsProvider.notifier).save(
            exerciseId: exercise.id,
            warmupSets: result.warmupSets,
            approachSets: result.approachSets,
            technicalNotes: notesController.text,
          );
      if (!mounted) {
        notesController.dispose();
        return;
      }
      setState(() {
        if (index == null) {
          _selectedExercises.add(result);
        } else {
          _selectedExercises[index] = result;
        }
        _replaceExercises(_selectedExercises);
      });
    }
    notesController.dispose();
  }

  Future<void> _showSupersetManager() async {
    if (_selectedExercises.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade al menos dos ejercicios para crear una superserie.'),
        ),
      );
      return;
    }

    var firstIndex = 0;
    var secondIndex = 1;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final groups = RoutineSupersetCoordinator.groups(_selectedExercises);
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.link, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Superseries de la rutina'),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estos pares se cargarán automáticamente cada vez que inicies esta rutina.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (groups.isEmpty)
                      _EmptySupersetState()
                    else
                      ...groups.entries.map((entry) {
                        final indexes = entry.value;
                        final names = indexes
                            .map((itemIndex) => _exerciseName(itemIndex))
                            .join('  +  ');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFaded,
                            borderRadius: AppRadius.md_,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(names, style: AppTypography.bodyMedium),
                              ),
                              IconButton(
                                tooltip: 'Quitar superserie',
                                onPressed: () {
                                  setState(() {
                                    _replaceExercises(
                                      RoutineSupersetCoordinator.unpair(
                                        _selectedExercises,
                                        indexes.first,
                                      ),
                                    );
                                  });
                                  setDialogState(() {});
                                },
                                icon: const Icon(
                                  Icons.link_off,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    Text('Crear un par', style: AppTypography.headlineSmall),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: firstIndex,
                      decoration: const InputDecoration(labelText: 'Ejercicio A'),
                      items: List.generate(
                        _selectedExercises.length,
                        (itemIndex) => DropdownMenuItem(
                          value: itemIndex,
                          child: Text(
                            _exerciseName(itemIndex),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          firstIndex = value;
                          if (secondIndex == firstIndex) {
                            secondIndex = firstIndex == 0 ? 1 : 0;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'web-routine-superset-$firstIndex-$secondIndex',
                      ),
                      initialValue: secondIndex,
                      decoration: const InputDecoration(labelText: 'Ejercicio B'),
                      items: List.generate(
                        _selectedExercises.length,
                        (itemIndex) => itemIndex,
                      )
                          .where((itemIndex) => itemIndex != firstIndex)
                          .map(
                            (itemIndex) => DropdownMenuItem(
                              value: itemIndex,
                              child: Text(
                                _exerciseName(itemIndex),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => secondIndex = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final groupId =
                              'routine_superset_${DateTime.now().microsecondsSinceEpoch}';
                          setState(() {
                            _replaceExercises(
                              RoutineSupersetCoordinator.pair(
                                _selectedExercises,
                                firstIndex,
                                secondIndex,
                                groupId,
                              ),
                            );
                          });
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.add_link),
                        label: const Text('Crear superserie'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _exerciseName(int index) {
    final id = _selectedExercises[index].exerciseId;
    final allExercises = ref.read(exerciseListProvider);
    for (final exercise in allExercises) {
      if (exercise.id == id) return exercise.name;
    }
    return 'Ejercicio ${index + 1}';
  }

  void _removeExercise(int index) {
    setState(() {
      final unpaired = RoutineSupersetCoordinator.unpair(
        _selectedExercises,
        index,
      );
      final updated = List<RoutineExercise>.from(unpaired)..removeAt(index);
      _replaceExercises(updated);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la rutina.')),
      );
      return;
    }
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio.')),
      );
      return;
    }

    final existing = widget.editingRoutine;
    final routine = Routine(
      id: existing?.id ?? 'routine_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      scheduledDays: _scheduledDays.toList()..sort(),
      exercises: RoutineOrderCoordinator.normalize(
        RoutineSupersetCoordinator.normalize(_selectedExercises),
      ),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    if (existing == null) {
      ref.read(routineListProvider.notifier).addRoutine(routine);
    } else {
      ref.read(routineListProvider.notifier).updateRoutine(routine);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final allExercises = ref.watch(exerciseListProvider);
    final byId = {for (final exercise in allExercises) exercise.id: exercise};
    final editing = widget.editingRoutine != null;
    final supersetCount =
        RoutineSupersetCoordinator.groups(_selectedExercises).length;

    final form = _RoutineDetails(
      nameController: _nameController,
      scheduledDays: _scheduledDays,
      onToggleDay: (day) => setState(() {
        _scheduledDays.contains(day)
            ? _scheduledDays.remove(day)
            : _scheduledDays.add(day);
      }),
    );
    final exercises = _ExerciseSelection(
      selected: _selectedExercises,
      exerciseMap: byId,
      onAdd: _pickExercise,
      onRemove: _removeExercise,
      onEdit: _editExercise,
      onReorder: _reorderExercises,
      onManageSupersets: _showSupersetManager,
      supersetCount: supersetCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(editing ? 'Editar rutina' : 'Nueva rutina'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                    children: [
                      form,
                      const SizedBox(height: 16),
                      exercises,
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 340, child: form),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: exercises,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineDetails extends StatelessWidget {
  final TextEditingController nameController;
  final Set<int> scheduledDays;
  final ValueChanged<int> onToggleDay;

  const _RoutineDetails({
    required this.nameController,
    required this.scheduledDays,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalles', style: AppTypography.headlineLarge),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina',
              hintText: 'Ej. Push A',
            ),
          ),
          const SizedBox(height: 24),
          Text('Días de entrenamiento', style: AppTypography.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final day = index + 1;
              return FilterChip(
                label: Text(_CreateRoutinePageWebState._days[index]),
                selected: scheduledDays.contains(day),
                onSelected: (_) => onToggleDay(day),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Los días son opcionales; sirven para mostrar qué entrenamiento toca hoy.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSelection extends StatelessWidget {
  final List<RoutineExercise> selected;
  final Map<String, Exercise> exerciseMap;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, Exercise exercise) onEdit;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onManageSupersets;
  final int supersetCount;

  const _ExerciseSelection({
    required this.selected,
    required this.exerciseMap,
    required this.onAdd,
    required this.onRemove,
    required this.onEdit,
    required this.onReorder,
    required this.onManageSupersets,
    required this.supersetCount,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Ejercicios', style: AppTypography.headlineLarge),
              if (selected.length >= 2)
                OutlinedButton.icon(
                  onPressed: onManageSupersets,
                  icon: Icon(
                    Icons.link,
                    color: supersetCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  label: Text(
                    supersetCount > 0
                        ? 'Superseries ($supersetCount)'
                        : 'Superseries',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Arrastra el asa para definir el orden de ejecución.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (selected.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: 0.45),
                borderRadius: AppRadius.md_,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Selecciona los ejercicios que formarán tu rutina.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: selected.length,
              onReorder: onReorder,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 8,
                borderRadius: AppRadius.md_,
                child: child,
              ),
              itemBuilder: (context, index) {
                final item = selected[index];
                final exercise = exerciseMap[item.exerciseId];
                final extras = <String>[
                  if (item.warmupSets > 0) '${item.warmupSets} calent.',
                  if (item.approachSets > 0) '${item.approachSets} aprox.',
                  if (item.unilateral) '${item.unilateralTarget.label} I/D',
                  if (item.isInSuperset) 'Superserie',
                ];

                return Container(
                  key: ValueKey(
                    '${item.exerciseId}-${item.order}-${item.supersetGroupId ?? 'solo'}',
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: AppRadius.md_,
                    border: Border.all(
                      color: item.isInSuperset
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: AppRadius.md_,
                    onTap: exercise == null
                        ? null
                        : () => onEdit(index, exercise),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: Tooltip(
                              message: 'Arrastrar para reordenar',
                              child: Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: item.isInSuperset
                                      ? AppColors.primaryFaded
                                      : AppColors.background,
                                  borderRadius: AppRadius.sm_,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Icon(
                                  item.isInSuperset
                                      ? Icons.link
                                      : Icons.drag_indicator,
                                  color: item.isInSuperset
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise?.name ?? 'Ejercicio eliminado',
                                  style: AppTypography.headlineSmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.targetSets} trabajo · ${item.targetRepsMin}-${item.targetRepsMax} reps · ${item.restSeconds}s${extras.isEmpty ? '' : ' · ${extras.join(' · ')}'}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.tune,
                            color: AppColors.textSecondary,
                          ),
                          IconButton(
                            onPressed: () => onRemove(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Quitar',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptySupersetState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: const Text('No hay superseries configuradas.'),
    );
  }
}

class _DialogSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _DialogSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.low,
      ),
      child: child,
    );
  }
}
