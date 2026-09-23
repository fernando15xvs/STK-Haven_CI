import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/active_workout_suggestions_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:gym_tracker/features/workout/presentation/workout_summary_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/barbell_calculator_modal.dart';

class ActiveWorkoutPage extends ConsumerStatefulWidget {
  const ActiveWorkoutPage({super.key});

  @override
  ConsumerState<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends ConsumerState<ActiveWorkoutPage> {
  bool _isFinishing = false;
  bool _focusMode = false;
  int _focusIndex = 0;

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _currentExerciseIndex(WorkoutSession session) {
    final index = session.exercises.indexWhere((exercise) => !exercise.completed);
    if (index >= 0) return index;
    return session.exercises.isEmpty ? 0 : session.exercises.length - 1;
  }

  void _toggleFocus(WorkoutSession session) {
    if (session.exercises.isEmpty) return;
    setState(() {
      _focusMode = !_focusMode;
      if (_focusMode) {
        _focusIndex = _currentExerciseIndex(session);
      }
    });
  }

  Future<void> _showCreateSupersetDialog(WorkoutSession session) async {
    if (session.exercises.length < 2) return;
    var firstIndex = 0;
    var secondIndex = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text('Crear superserie', style: AppTypography.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El descanso automático empezará después de completar la misma ronda en ambos ejercicios.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: firstIndex,
                decoration: const InputDecoration(labelText: 'Ejercicio A'),
                items: List.generate(
                  session.exercises.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(
                      session.exercises[index].exerciseNameSnapshot,
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: secondIndex,
                decoration: const InputDecoration(labelText: 'Ejercicio B'),
                items: List.generate(session.exercises.length, (index) => index)
                    .where((index) => index != firstIndex)
                    .map(
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(
                          session.exercises[index].exerciseNameSnapshot,
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.link),
              label: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      ref
          .read(activeWorkoutProvider.notifier)
          .createSuperset(firstIndex, secondIndex);
    }
  }

  Future<void> _showSupersetManager() async {
    final current = ref.read(activeWorkoutProvider).session;
    if (current == null) return;
    if (current.exercises.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas al menos dos ejercicios para crear una superserie.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final session = ref.watch(activeWorkoutProvider).session;
            if (session == null) return const SizedBox.shrink();

            final groups = <String, List<int>>{};
            for (var index = 0; index < session.exercises.length; index++) {
              final groupId = session.exercises[index].supersetGroupId;
              if (groupId != null) {
                groups.putIfAbsent(groupId, () => <int>[]).add(index);
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            Text('Superseries', style: AppTypography.headlineLarge),
                            Text(
                              'Entrena A → B y descansa al cerrar la ronda.',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (groups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.md_,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        'Todavía no has creado superseries en esta sesión.',
                        style: AppTypography.bodyMedium,
                      ),
                    )
                  else
                    ...groups.entries.map((entry) {
                      final indexes = entry.value;
                      if (indexes.isEmpty) return const SizedBox.shrink();
                      final names = indexes
                          .map((index) =>
                              session.exercises[index].exerciseNameSnapshot)
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
                              onPressed: () => ref
                                  .read(activeWorkoutProvider.notifier)
                                  .removeSuperset(indexes.first),
                              icon: const Icon(
                                Icons.link_off,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showCreateSupersetDialog(session),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Crear superserie'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String?> _showLeaveDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          'Entrenamiento en curso',
          style: AppTypography.headlineMedium,
        ),
        content: Text('¿Qué deseas hacer?', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('continue'),
            child: const Text(
              'Continuar',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('finish'),
            child: const Text(
              'Finalizar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    final result =
        await ref.read(activeWorkoutProvider.notifier).finishWorkout();
    if (!context.mounted) return;
    setState(() => _isFinishing = false);

    if (result is WorkoutFinished) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryPage(analysisResult: result.analysis),
        ),
      );
    } else if (result is EmptyWorkout) {
      _showEmptyWorkoutDialog(context, ref);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeState = ref.watch(activeWorkoutProvider);
    final session = activeState.session;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'No hay entrenamiento activo',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    if (session.exercises.isNotEmpty && _focusIndex >= session.exercises.length) {
      _focusIndex = session.exercises.length - 1;
    }
    final hasSupersets =
        session.exercises.any((exercise) => exercise.supersetGroupId != null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final choice = await _showLeaveDialog(context);
        if (!context.mounted) return;

        if (choice == 'discard') {
          await ref.read(activeWorkoutProvider.notifier).cancelWorkout();
          if (context.mounted) Navigator.of(context).pop();
        } else if (choice == 'finish') {
          await _finish(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeState.routineDisplayName,
                style: AppTypography.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Consumer(
                builder: (context, ref, child) {
                  final timerValue = ref.watch(workoutTimerProvider).value ??
                      activeState.globalTimerSeconds;
                  return Text(
                    _formatTime(timerValue),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _focusMode
                    ? Icons.view_agenda_outlined
                    : Icons.center_focus_strong_outlined,
                color: _focusMode ? AppColors.primary : AppColors.textSecondary,
              ),
              onPressed:
                  session.exercises.isEmpty ? null : () => _toggleFocus(session),
              tooltip: _focusMode ? 'Ver todos los ejercicios' : 'Modo enfoque',
            ),
            IconButton(
              icon: Icon(
                Icons.link,
                color: hasSupersets ? AppColors.primary : AppColors.textSecondary,
              ),
              onPressed:
                  session.exercises.length < 2 ? null : _showSupersetManager,
              tooltip: 'Superseries',
            ),
            IconButton(
              icon: const Icon(
                Icons.calculate_outlined,
                color: AppColors.primary,
              ),
              onPressed: () => BarbellCalculatorModal.show(context),
              tooltip: 'Calculadora de Discos',
            ),
          ],
        ),
        body: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: activeState.isResting
                  ? Container(
                      key: const ValueKey('rest_banner'),
                      color: AppColors.primaryFaded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Descanso ${_formatTime(activeState.restTimerSeconds)}',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(activeWorkoutProvider.notifier)
                                .skipRest(),
                            child: const Text('Omitir'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_rest')),
            ),
            Expanded(
              child: _focusMode && session.exercises.isNotEmpty
                  ? _FocusedWorkoutView(
                      session: session,
                      focusIndex: _focusIndex,
                      onPrevious: _focusIndex > 0
                          ? () => setState(() => _focusIndex--)
                          : null,
                      onNext: _focusIndex < session.exercises.length - 1
                          ? () => setState(() => _focusIndex++)
                          : null,
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                      itemCount: session.exercises.length,
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(activeWorkoutProvider.notifier)
                            .reorderExercises(oldIndex, newIndex);
                      },
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      footer: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final Exercise? selected =
                                await Navigator.push<Exercise>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExerciseLibraryPage(
                                  isSelectionMode: true,
                                ),
                              ),
                            );
                            if (selected != null && context.mounted) {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .addExercise(selected);
                            }
                          },
                          icon: const Icon(Icons.add, color: AppColors.primary),
                          label: const Text(
                            'AÑADIR EJERCICIO',
                            style: TextStyle(color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: AppColors.primaryFaded,
                          ),
                        ),
                      ),
                      itemBuilder: (context, exIndex) {
                        final currentActiveIndex = session.exercises.indexWhere(
                          (e) => !e.completed,
                        );
                        final isCurrent = exIndex == currentActiveIndex ||
                            (currentActiveIndex == -1 &&
                                exIndex == session.exercises.length - 1);

                        return Padding(
                          key: ValueKey(session.exercises[exIndex].exerciseId),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExerciseBlock(
                            exIndex: exIndex,
                            workoutExercise: session.exercises[exIndex],
                            isCurrent: isCurrent,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: 'Finalizar',
            onPressed: () => _finish(context),
          ),
        ),
      ),
    );
  }

  void _showEmptyWorkoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text(
          'Entrenamiento vacío',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'No has completado ninguna serie. ¿Qué deseas hacer?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Continuar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(activeWorkoutProvider.notifier).cancelWorkout();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedWorkoutView extends StatelessWidget {
  final WorkoutSession session;
  final int focusIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _FocusedWorkoutView({
    required this.session,
    required this.focusIndex,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = session.exercises[focusIndex];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryFaded,
            borderRadius: AppRadius.md_,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Ejercicio anterior',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'MODO ENFOQUE',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${focusIndex + 1} de ${session.exercises.length}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Ejercicio siguiente',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ExerciseBlock(
          key: ValueKey('focus_${exercise.exerciseId}'),
          exIndex: focusIndex,
          workoutExercise: exercise,
          isCurrent: true,
          forceExpanded: true,
        ),
      ],
    );
  }
}

class _ExerciseBlock extends ConsumerStatefulWidget {
  final int exIndex;
  final WorkoutExercise workoutExercise;
  final bool isCurrent;
  final bool forceExpanded;

  const _ExerciseBlock({
    super.key,
    required this.exIndex,
    required this.workoutExercise,
    required this.isCurrent,
    this.forceExpanded = false,
  });

  @override
  ConsumerState<_ExerciseBlock> createState() => _ExerciseBlockState();
}

class _ExerciseBlockState extends ConsumerState<_ExerciseBlock> {
  bool? _manuallyExpanded;

  @override
  void didUpdateWidget(covariant _ExerciseBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.workoutExercise.completed &&
        widget.workoutExercise.completed &&
        !widget.forceExpanded) {
      _manuallyExpanded = false;
    }
  }

  Future<void> _configureUnilateral() async {
    bool unilateral = widget.workoutExercise.unilateral;
    UnilateralTarget target = widget.workoutExercise.unilateralTarget;
    final result = await showDialog<(bool, UnilateralTarget)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(
            'Registro unilateral',
            style: AppTypography.headlineMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Separar izquierda y derecha'),
                subtitle: const Text(
                  'La serie se completa cuando marcas ambos lados.',
                ),
                value: unilateral,
                onChanged: (value) =>
                    setDialogState(() => unilateral = value),
              ),
              if (unilateral)
                DropdownButtonFormField<UnilateralTarget>(
                  value: target,
                  decoration: const InputDecoration(labelText: 'Zona'),
                  items: UnilateralTarget.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => target = value);
                    }
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (unilateral, target)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).configureExerciseUnilateral(
          widget.exIndex,
          unilateral: result.$1,
          target: result.$2,
        );
  }

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: widget.workoutExercise.notes);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nota del ejercicio', style: AppTypography.headlineMedium),
            const SizedBox(height: 6),
            Text(
              widget.workoutExercise.exerciseNameSnapshot,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Ej.: cuidar técnica, agarre, dolor, ajuste del banco...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar nota'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      ref
          .read(activeWorkoutProvider.notifier)
          .updateExerciseNotes(widget.exIndex, controller.text);
    }
    controller.dispose();
  }

  Future<void> _replaceExercise() async {
    final hasCompletedWork = widget.workoutExercise.sets.any(
      (set) => set.completed || set.leftCompleted || set.rightCompleted,
    );
    if (hasCompletedWork) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes sustituir este ejercicio después de completar series. Añade otro ejercicio para conservar el historial correctamente.',
          ),
        ),
      );
      return;
    }

    final selected = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryPage(isSelectionMode: true),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.id == widget.workoutExercise.exerciseId) return;

    final replaced = ref
        .read(activeWorkoutProvider.notifier)
        .replaceExercise(widget.exIndex, selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          replaced
              ? 'Ejercicio sustituido por ${selected.name}.'
              : 'No se pudo sustituir el ejercicio porque ya tiene trabajo completado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final suggestions = ref.watch(activeWorkoutSuggestionsProvider);
    final suggestion = suggestions[widget.workoutExercise.exerciseId];
    final prevSession = ref.watch(activeWorkoutPreviousSessionProvider);
    final completed = widget.workoutExercise.completed;
    final expanded = widget.forceExpanded ||
        (_manuallyExpanded ??
            (widget.isCurrent && !widget.workoutExercise.completed));

    WorkoutExercise? prevExercise;
    if (prevSession != null) {
      for (final item in prevSession.exercises) {
        if (item.exerciseId == widget.workoutExercise.exerciseId) {
          prevExercise = item;
          break;
        }
      }
    }

    final workingSets = widget.workoutExercise.sets
        .where((set) => set.setType == WorkoutSetType.working)
        .toList();
    final doneWorking = workingSets.where((set) => set.completed).length;
    final leftDone = widget.workoutExercise.sets
        .where((set) => set.leftCompleted)
        .length;
    final rightDone = widget.workoutExercise.sets
        .where((set) => set.rightCompleted)
        .length;

    double totalVolume = 0;
    for (final set in workingSets) {
      if (set.completed) totalVolume += set.performedVolume;
    }
    final volumeText =
        '${WeightConverter.displayWeight(totalVolume, settings.weightUnit).toStringAsFixed(1)} ${settings.weightUnit.label}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: expanded ? AppColors.surface : AppColors.surfaceHigh,
        borderRadius: AppRadius.lg_,
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.3)
              : widget.workoutExercise.isInSuperset
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : widget.isCurrent
                      ? AppColors.primary.withValues(alpha: 0.32)
                      : AppColors.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: AppRadius.lg_,
            onTap: widget.forceExpanded
                ? null
                : () => setState(() => _manuallyExpanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? AppColors.successFaded
                          : widget.isCurrent
                              ? AppColors.primaryFaded
                              : AppColors.background,
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : widget.workoutExercise.isInSuperset
                              ? Icons.link
                              : Icons.fitness_center,
                      color: completed
                          ? AppColors.success
                          : widget.workoutExercise.isInSuperset
                              ? AppColors.primary
                              : widget.isCurrent
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workoutExercise.exerciseNameSnapshot,
                          style: AppTypography.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (widget.workoutExercise.unilateral)
                          Text(
                            '${widget.workoutExercise.unilateralTarget.label} · I $leftDone/${widget.workoutExercise.sets.length} · D $rightDone/${widget.workoutExercise.sets.length}${widget.workoutExercise.isInSuperset ? ' · Superserie' : ''}',
                            style: AppTypography.bodySmall.copyWith(
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          )
                        else
                          Text(
                            '${completed ? '$doneWorking series de trabajo · $volumeText' : '$doneWorking/${workingSets.length} series de trabajo'}${widget.workoutExercise.isInSuperset ? ' · Superserie' : ''}',
                            style: AppTypography.bodySmall.copyWith(
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.forceExpanded)
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.workoutExercise.muscleGroupSnapshot,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      IconButton(
                        onPressed: _editNotes,
                        tooltip: 'Nota rápida',
                        icon: Icon(
                          Icons.edit_note_outlined,
                          color: widget.workoutExercise.notes.trim().isNotEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        onPressed: _replaceExercise,
                        tooltip: 'Sustituir ejercicio',
                        icon: const Icon(
                          Icons.swap_horiz,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        onPressed: _configureUnilateral,
                        tooltip: widget.workoutExercise.unilateral
                            ? 'Unilateral: ${widget.workoutExercise.unilateralTarget.label}'
                            : 'Configurar unilateral',
                        icon: Icon(
                          Icons.compare_arrows,
                          color: widget.workoutExercise.unilateral
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (widget.workoutExercise.isInSuperset) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: AppRadius.sm_,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Superserie activa: completa la ronda en ambos ejercicios antes del descanso.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.workoutExercise.notes.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: AppRadius.sm_,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.workoutExercise.notes,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.workoutExercise.unilateral)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaded,
                        borderRadius: AppRadius.sm_,
                      ),
                      child: Text(
                        '${widget.workoutExercise.unilateralTarget.label}: registra un lado, descansa ${settings.unilateralSideRestSeconds}s y registra el otro. Peso, reps y RIR se guardan por lado.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (suggestion != null) ...[
                    const SizedBox(height: 10),
                    _ProgressionReferenceCard(
                      suggestion: suggestion,
                      unit: settings.weightUnit,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('SERIE', style: AppTypography.labelSmall),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'ANTERIOR',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          settings.weightUnit.label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'REPS',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall,
                        ),
                      ),
                      if (settings.isRirEnabled)
                        Expanded(
                          flex: 2,
                          child: Text(
                            'RIR',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSmall,
                          ),
                        ),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(widget.workoutExercise.sets.length, (setIndex) {
                    final set = widget.workoutExercise.sets[setIndex];
                    final prevSet = prevExercise != null &&
                            setIndex < prevExercise.sets.length
                        ? prevExercise.sets[setIndex]
                        : null;
                    return _SetRow(
                      key: ValueKey(
                        '${widget.workoutExercise.exerciseId}_$setIndex',
                      ),
                      exIndex: widget.exIndex,
                      setIndex: setIndex,
                      initialSet: set,
                      isRirEnabled: settings.isRirEnabled &&
                          set.setType == WorkoutSetType.working,
                      weightUnit: settings.weightUnit,
                      vibrationEnabled: settings.vibrationEnabled,
                      prevSet: prevSet,
                      unilateral: widget.workoutExercise.unilateral,
                      unilateralTarget:
                          widget.workoutExercise.unilateralTarget,
                    );
                  }),
                  const SizedBox(height: 6),
                  PopupMenuButton<WorkoutSetType>(
                    onSelected: (type) => ref
                        .read(activeWorkoutProvider.notifier)
                        .addSet(widget.exIndex, setType: type),
                    itemBuilder: (_) => WorkoutSetType.values
                        .map(
                          (type) => PopupMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                _SetTypeBadge(type: type),
                                const SizedBox(width: 10),
                                Text('Serie de ${type.label.toLowerCase()}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.sm_,
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 17),
                          SizedBox(width: 6),
                          Text('Añadir serie'),
                          Icon(Icons.arrow_drop_down, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetTypeBadge extends StatelessWidget {
  final WorkoutSetType type;

  const _SetTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      WorkoutSetType.warmup => AppColors.warning,
      WorkoutSetType.approach => AppColors.gold,
      WorkoutSetType.working => AppColors.primary,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type.shortLabel,
        textAlign: TextAlign.center,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _SetRow extends ConsumerStatefulWidget {
  final int exIndex;
  final int setIndex;
  final WorkoutSet initialSet;
  final bool isRirEnabled;
  final WeightUnit weightUnit;
  final bool vibrationEnabled;
  final WorkoutSet? prevSet;
  final bool unilateral;
  final UnilateralTarget unilateralTarget;

  const _SetRow({
    super.key,
    required this.exIndex,
    required this.setIndex,
    required this.initialSet,
    required this.isRirEnabled,
    required this.weightUnit,
    required this.vibrationEnabled,
    required this.prevSet,
    required this.unilateral,
    required this.unilateralTarget,
  });

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late TextEditingController _rirCtrl;
  Timer? _debounce;

  String _fmt(double value) =>
      value % 1 == 0 ? '${value.toInt()}' : '$value';

  String _displayWeight(double canonicalKg) {
    if (canonicalKg == 0) return '';
    return _fmt(
      WeightConverter.displayWeight(canonicalKg, widget.weightUnit),
    );
  }

  String _sidePerformanceLabel(WorkoutSide side) {
    final short = side.shortLabel;
    if (!widget.initialSet.completedForSide(side)) {
      return side == WorkoutSide.left ? 'Izq.' : 'Der.';
    }
    final displayedWeight = WeightConverter.displayWeight(
      widget.initialSet.weightForSide(side),
      widget.weightUnit,
    );
    final reps = widget.initialSet.repsForSide(side);
    final rir = widget.initialSet.rirForSide(side);
    return '$short ${_fmt(displayedWeight)}×$reps${rir == null ? '' : '@$rir'}';
  }

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: _displayWeight(widget.initialSet.weight),
    );
    _repsCtrl = TextEditingController(
      text: widget.initialSet.reps == 0 ? '' : '${widget.initialSet.reps}',
    );
    _rirCtrl = TextEditingController(
      text: widget.initialSet.rir == null ? '' : '${widget.initialSet.rir}',
    );
  }

  @override
  void didUpdateWidget(_SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final unitChanged = oldWidget.weightUnit != widget.weightUnit;
    final weightChanged =
        oldWidget.initialSet.weight != widget.initialSet.weight;
    if ((unitChanged || weightChanged) && !widget.initialSet.completed) {
      final newText = _displayWeight(widget.initialSet.weight);
      if (_weightCtrl.text != newText) _weightCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _rirCtrl.dispose();
    super.dispose();
  }

  WorkoutSet _setFromFields({bool? completed}) {
    final displayWeight = double.tryParse(_weightCtrl.text) ?? 0;
    final canonicalWeight =
        WeightConverter.toCanonicalKg(displayWeight, widget.weightUnit);
    final reps = int.tryParse(_repsCtrl.text) ?? 0;
    final rir = int.tryParse(_rirCtrl.text);
    return widget.initialSet.copyWith(
      weight: canonicalWeight,
      reps: reps,
      rir: rir,
      clearRir: _rirCtrl.text.isEmpty,
      completed: completed,
    );
  }

  void _flushDebounce() {
    if (!widget.initialSet.completed) {
      ref.read(activeWorkoutProvider.notifier).updateSet(
            widget.exIndex,
            widget.setIndex,
            _setFromFields(),
          );
    }
  }

  void _onFieldChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flushDebounce);
  }

  void _toggle() {
    _debounce?.cancel();
    if (!widget.initialSet.completed && widget.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    ref.read(activeWorkoutProvider.notifier).updateSet(
          widget.exIndex,
          widget.setIndex,
          _setFromFields(completed: !widget.initialSet.completed),
        );
  }

  void _toggleSide(bool left) {
    _debounce?.cancel();
    _flushDebounce();
    if (widget.vibrationEnabled) HapticFeedback.selectionClick();
    ref.read(activeWorkoutProvider.notifier).toggleUnilateralSide(
          widget.exIndex,
          widget.setIndex,
          left: left,
        );
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.initialSet.completed;
    String prevText = '-';
    if (widget.prevSet != null) {
      final prevW = WeightConverter.displayWeight(
        widget.prevSet!.weight,
        widget.weightUnit,
      );
      prevText = '${_fmt(prevW)}×${widget.prevSet!.reps}';
    }

    return GestureDetector(
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surfaceHigh,
            title: Text('Eliminar serie', style: AppTypography.headlineMedium),
            content: Text(
              '¿Deseas eliminar esta serie de ${widget.initialSet.setType.label.toLowerCase()}?',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          ref
              .read(activeWorkoutProvider.notifier)
              .removeSet(widget.exIndex, widget.setIndex);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: done ? AppColors.successFaded : Colors.transparent,
          borderRadius: AppRadius.sm_,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      _SetTypeBadge(type: widget.initialSet.setType),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.setIndex + 1}',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    prevText,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _MinimalCell(
                    controller: _weightCtrl,
                    enabled: !done,
                    done: done,
                    onChanged: (_) => _onFieldChanged(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _MinimalCell(
                    controller: _repsCtrl,
                    enabled: !done,
                    done: done,
                    onChanged: (_) => _onFieldChanged(),
                  ),
                ),
                if (widget.isRirEnabled)
                  Expanded(
                    flex: 2,
                    child: _MinimalCell(
                      controller: _rirCtrl,
                      enabled: !done,
                      done: done,
                      hint: '-',
                      onChanged: (_) => _onFieldChanged(),
                    ),
                  )
                else
                  const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: widget.unilateral
                      ? Icon(
                          done ? Icons.done_all : Icons.compare_arrows,
                          color: done
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 18,
                        )
                      : GestureDetector(
                          onTap: _toggle,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color:
                                  done ? AppColors.success : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: done
                                  ? null
                                  : Border.all(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.3),
                                    ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Icon(
                              Icons.check,
                              size: 15,
                              color: done
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (widget.unilateral) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideButton(
                        label: _sidePerformanceLabel(WorkoutSide.left),
                        selected: widget.initialSet.leftCompleted,
                        onTap: () => _toggleSide(true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _SideButton(
                        label: _sidePerformanceLabel(WorkoutSide.right),
                        selected: widget.initialSet.rightCompleted,
                        onTap: () => _toggleSide(false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.initialSet.sideRestSeconds == 0
                    ? 'Sin descanso automático entre lados'
                    : 'Descanso entre lados: ${widget.initialSet.sideRestSeconds}s',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm_,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.successFaded : AppColors.surface,
          borderRadius: AppRadius.sm_,
          border: Border.all(
            color: selected ? AppColors.success : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.success : AppColors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalCell extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool done;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _MinimalCell({
    required this.controller,
    required this.enabled,
    required this.done,
    this.hint = '-',
    this.onChanged,
  });

  @override
  State<_MinimalCell> createState() => _MinimalCellState();
}

class _MinimalCellState extends State<_MinimalCell> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: widget.done
                ? Colors.transparent
                : _isFocused
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.3),
            width: _isFocused ? 2 : 1,
          ),
        ),
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.monoMedium.copyWith(
          color: widget.done
              ? AppColors.textSecondary
              : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: AppTypography.monoMedium.copyWith(
            color: AppColors.textDisabled,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
        ),
        enabled: widget.enabled,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _ProgressionReferenceCard extends StatelessWidget {
  final ProgressionSuggestion suggestion;
  final WeightUnit unit;

  const _ProgressionReferenceCard({
    required this.suggestion,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = _progressionColor(suggestion);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.sm_,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_progressionIcon(suggestion), color: color, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  FitnessFormatter.progressionTitle(suggestion),
                  style: AppTypography.labelMedium.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            FitnessFormatter.progressionExplanation(suggestion),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (suggestion.type != ProgressionType.insufficientData) ...[
            const SizedBox(height: 5),
            Text(
              'Referencia: ${FitnessFormatter.formatProgressionTarget(suggestion.suggestedWeightKg, suggestion.suggestedRepsMin, suggestion.suggestedRepsMax, unit)}',
              style: AppTypography.bodySmall.copyWith(color: color),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            FitnessFormatter.progressionEvidence(suggestion),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FitnessFormatter.progressionSafetyNote,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDisabled,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

Color _progressionColor(ProgressionSuggestion suggestion) {
  if (suggestion.reason == ProgressionReason.recoveryCaution ||
      suggestion.reason == ProgressionReason.effortTooHigh) {
    return AppColors.warning;
  }
  return switch (suggestion.type) {
    ProgressionType.increase => AppColors.success,
    ProgressionType.maintain => AppColors.info,
    ProgressionType.deload => AppColors.warning,
    ProgressionType.insufficientData => AppColors.textSecondary,
  };
}

IconData _progressionIcon(ProgressionSuggestion suggestion) {
  return switch (suggestion.type) {
    ProgressionType.increase => Icons.trending_up,
    ProgressionType.maintain => Icons.horizontal_rule_rounded,
    ProgressionType.deload => Icons.south_rounded,
    ProgressionType.insufficientData => Icons.more_horiz_rounded,
  };
}
