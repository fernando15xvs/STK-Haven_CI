import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/routines/application/routine_order_coordinator.dart';
import 'package:core/features/routines/application/routine_superset_coordinator.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_personal_settings_provider.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/section_heading.dart';

class CreateRoutinePage extends ConsumerStatefulWidget {
  final Routine? editingRoutine;

  const CreateRoutinePage({super.key, this.editingRoutine});

  @override
  ConsumerState<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends ConsumerState<CreateRoutinePage> {
  final _nameController = TextEditingController();
  final List<RoutineExercise> _selectedExercises = [];
  final _uuid = const Uuid();
  final Set<int> _scheduledDays = {};

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

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

  Future<void> _addExercise() async {
    final selected = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryPage(isSelectionMode: true),
      ),
    );
    if (selected == null || !mounted) return;
    _showExerciseConfig(selected);
  }

  void _editExercise(int index, Exercise exercise) {
    _showExerciseConfig(exercise, index: index);
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

  void _showExerciseConfig(Exercise exercise, {int? index}) {
    final current = index == null ? null : _selectedExercises[index];
    final personal = ref
        .read(exercisePersonalSettingsProvider.notifier)
        .settingsFor(exercise.id);
    final notesController = TextEditingController(text: personal.technicalNotes);
    int sets = current?.targetSets ?? 3;
    int repsMin = current?.targetRepsMin ?? 8;
    int repsMax = current?.targetRepsMax ?? 12;
    int rest = current?.restSeconds ?? 90;
    int warmupSets = current?.warmupSets ?? personal.warmupSets;
    int approachSets = current?.approachSets ?? personal.approachSets;
    bool unilateral = current?.unilateral ?? false;
    UnilateralTarget unilateralTarget =
        current?.unilateralTarget ?? UnilateralTarget.other;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomState) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              18,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(exercise.name, style: AppTypography.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  'Configura solo lo que este ejercicio necesita.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 22),
                _ConfigSection(
                  title: 'Series efectivas',
                  child: Column(
                    children: [
                      _CounterRow(
                        label: 'Series de trabajo',
                        value: sets,
                        min: 1,
                        max: 10,
                        onChanged: (value) =>
                            setBottomState(() => sets = value),
                      ),
                      const SizedBox(height: 10),
                      _CounterRow(
                        label: 'Reps mínimas',
                        value: repsMin,
                        min: 1,
                        max: repsMax,
                        onChanged: (value) =>
                            setBottomState(() => repsMin = value),
                      ),
                      const SizedBox(height: 10),
                      _CounterRow(
                        label: 'Reps máximas',
                        value: repsMax,
                        min: repsMin,
                        max: 50,
                        onChanged: (value) =>
                            setBottomState(() => repsMax = value),
                      ),
                      const SizedBox(height: 10),
                      _CounterRow(
                        label: 'Descanso (s)',
                        value: rest,
                        min: 15,
                        max: 300,
                        step: 15,
                        onChanged: (value) =>
                            setBottomState(() => rest = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ConfigSection(
                  title: 'Preparación predeterminada',
                  subtitle:
                      'Se recordará para la próxima vez que añadas este ejercicio. Estas series no cuentan como efectivas ni para PRs.',
                  child: Column(
                    children: [
                      _CounterRow(
                        label: 'Calentamiento',
                        value: warmupSets,
                        min: 0,
                        max: 5,
                        onChanged: (value) =>
                            setBottomState(() => warmupSets = value),
                      ),
                      const SizedBox(height: 10),
                      _CounterRow(
                        label: 'Aproximación',
                        value: approachSets,
                        min: 0,
                        max: 5,
                        onChanged: (value) =>
                            setBottomState(() => approachSets = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ConfigSection(
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
                const SizedBox(height: 14),
                _ConfigSection(
                  title: 'Unilateral',
                  subtitle:
                      'Úsalo cuando trabajas un lado a la vez. Podrás marcar Izq. y Der. por separado.',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Registrar izquierda y derecha'),
                        value: unilateral,
                        activeTrackColor: AppColors.primary,
                        onChanged: (value) =>
                            setBottomState(() => unilateral = value),
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
                              setBottomState(
                                () => unilateralTarget = value,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      await ref
                          .read(exercisePersonalSettingsProvider.notifier)
                          .save(
                            exerciseId: exercise.id,
                            warmupSets: warmupSets,
                            approachSets: approachSets,
                            technicalNotes: notesController.text,
                          );
                      if (!mounted) return;
                      final configured = RoutineExercise(
                        exerciseId: exercise.id,
                        order: index ?? _selectedExercises.length,
                        targetSets: sets,
                        targetRepsMin: repsMin,
                        targetRepsMax: repsMax,
                        restSeconds: rest,
                        warmupSets: warmupSets,
                        approachSets: approachSets,
                        unilateral: unilateral,
                        unilateralTarget: unilateralTarget,
                        supersetGroupId: current?.supersetGroupId,
                      );
                      setState(() {
                        if (index == null) {
                          _selectedExercises.add(configured);
                        } else {
                          _selectedExercises[index] = configured;
                        }
                        _replaceExercises(_selectedExercises);
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      index == null ? 'Añadir ejercicio' : 'Guardar cambios',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(notesController.dispose);
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final groups = RoutineSupersetCoordinator.groups(_selectedExercises);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: AppRadius.sm_,
                      ),
                      child: const Icon(Icons.link, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Superseries de la rutina',
                            style: AppTypography.headlineLarge,
                          ),
                          Text(
                            'El par se cargará automáticamente al iniciar el entrenamiento.',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                              setSheetState(() {});
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
                    setSheetState(() {
                      firstIndex = value;
                      if (secondIndex == firstIndex) {
                        secondIndex = firstIndex == 0 ? 1 : 0;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey('routine-superset-$firstIndex-$secondIndex'),
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
                      setSheetState(() => secondIndex = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final groupId = 'routine_superset_${_uuid.v4()}';
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
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.add_link),
                    label: const Text('Crear superserie'),
                  ),
                ),
              ],
            ),
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

  void _saveRoutine() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un nombre.')),
      );
      return;
    }
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio.')),
      );
      return;
    }

    final routine = Routine(
      id: widget.editingRoutine?.id ?? _uuid.v4(),
      name: name,
      scheduledDays: _scheduledDays.toList()..sort(),
      exercises: RoutineOrderCoordinator.normalize(
        RoutineSupersetCoordinator.normalize(_selectedExercises),
      ),
      createdAt: widget.editingRoutine?.createdAt ?? DateTime.now(),
    );
    if (widget.editingRoutine != null) {
      ref.read(routineListProvider.notifier).updateRoutine(routine);
    } else {
      ref.read(routineListProvider.notifier).addRoutine(routine);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allExercises = ref.watch(exerciseListProvider);
    final supersetCount =
        RoutineSupersetCoordinator.groups(_selectedExercises).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingRoutine != null ? 'Editar Rutina' : 'Nueva Rutina',
          style: AppTypography.displaySmall,
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: Text(
              'Guardar',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          PremiumCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            child: TextField(
              controller: _nameController,
              style: AppTypography.headlineLarge,
              decoration: InputDecoration(
                hintText: 'Nombre de la rutina...',
                hintStyle: AppTypography.headlineLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeading(title: 'DÍAS DE ENTRENAMIENTO'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = index + 1;
              final selected = _scheduledDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  selected
                      ? _scheduledDays.remove(day)
                      : _scheduledDays.add(day);
                }),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : AppColors.surfaceHigh,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _dayLabels[index],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Row(
            children: [
              const Expanded(child: SectionHeading(title: 'EJERCICIOS')),
              if (_selectedExercises.length >= 2)
                TextButton.icon(
                  onPressed: _showSupersetManager,
                  icon: Icon(
                    Icons.link,
                    size: 16,
                    color: supersetCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  label: Text(
                    supersetCount > 0
                        ? 'Superseries ($supersetCount)'
                        : 'Superseries',
                    style: AppTypography.labelLarge.copyWith(
                      color: supersetCount > 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: Text(
                  'Añadir',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedExercises.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arrastra el asa para cambiar el orden',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedExercises.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Text(
                  'Añade ejercicios a tu rutina',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _selectedExercises.length,
              onReorder: _reorderExercises,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 8,
                borderRadius: AppRadius.lg_,
                child: child,
              ),
              itemBuilder: (context, index) {
                final item = _selectedExercises[index];
                final exercise = allExercises.firstWhere(
                  (candidate) => candidate.id == item.exerciseId,
                  orElse: () =>
                      Exercise(id: '', name: 'Desconocido', muscleGroup: ''),
                );
                final extras = <String>[
                  if (item.warmupSets > 0) '${item.warmupSets} calent.',
                  if (item.approachSets > 0) '${item.approachSets} aprox.',
                  if (item.unilateral) '${item.unilateralTarget.label} I/D',
                  if (item.isInSuperset) 'Superserie',
                ];

                return Padding(
                  key: ValueKey(
                    '${item.exerciseId}-${item.order}-${item.supersetGroupId ?? 'solo'}',
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: PremiumCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _editExercise(index, exercise),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: item.isInSuperset
                                ? AppColors.primaryFaded
                                : AppColors.surfaceHigh,
                            borderRadius: AppRadius.sm_,
                          ),
                          child: Icon(
                            item.isInSuperset ? Icons.link : Icons.drag_indicator,
                            color: item.isInSuperset
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      title: Text(
                        exercise.name,
                        style: AppTypography.headlineMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${item.targetSets} trabajo × ${item.targetRepsMin}-${item.targetRepsMax} · ${item.restSeconds}s${extras.isEmpty ? '' : ' · ${extras.join(' · ')}'}',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune,
                            color: AppColors.textSecondary,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _removeExercise(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.xxxl),
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
        color: AppColors.surface,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No hay superseries configuradas.',
        style: AppTypography.bodyMedium,
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ConfigSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
        ),
        Row(
          children: [
            IconButton.outlined(
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max).toInt())
                  : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max).toInt())
                  : null,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
