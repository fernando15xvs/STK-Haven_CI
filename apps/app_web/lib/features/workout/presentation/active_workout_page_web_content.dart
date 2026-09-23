import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/active_workout_suggestions_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../routines/presentation/exercise_picker_page_web.dart';
import 'barbell_calculator_dialog_web.dart';
import 'workout_summary_page_web.dart';

class ActiveWorkoutPageWeb extends ConsumerStatefulWidget {
  const ActiveWorkoutPageWeb({super.key});

  @override
  ConsumerState<ActiveWorkoutPageWeb> createState() =>
      _ActiveWorkoutPageWebState();
}

class _ActiveWorkoutPageWebState extends ConsumerState<ActiveWorkoutPageWeb> {
  int _selectedExercise = 0;
  bool _finishing = false;
  bool _focusMode = false;

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleFocus(WorkoutSession session) {
    if (session.exercises.isEmpty) return;
    setState(() {
      _focusMode = !_focusMode;
      if (_focusMode) {
        final current =
            session.exercises.indexWhere((exercise) => !exercise.completed);
        if (current >= 0) {
          _selectedExercise = current;
        } else if (_selectedExercise >= session.exercises.length) {
          _selectedExercise = session.exercises.length - 1;
        }
      }
    });
  }

  Future<void> _finishWorkout() async {
    final session = ref.read(activeWorkoutProvider).session;
    if (session == null || _finishing) return;

    final incomplete =
        session.exercises.where((exercise) => !exercise.completed).length;

    if (incomplete > 0) {
      final continueFinish = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aún faltan ejercicios'),
          content: Text(
            incomplete == 1
                ? 'Todavía tienes 1 ejercicio incompleto. ¿Seguro que deseas finalizar el entrenamiento?'
                : 'Todavía tienes $incomplete ejercicios incompletos. ¿Seguro que deseas finalizar el entrenamiento?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir entrenando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar de todos modos'),
            ),
          ],
        ),
      );
      if (continueFinish != true) return;
    }

    setState(() => _finishing = true);
    final result =
        await ref.read(activeWorkoutProvider.notifier).finishWorkout();
    if (!mounted) return;
    setState(() => _finishing = false);

    if (result is WorkoutFinished) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              WorkoutSummaryPageWeb(analysisResult: result.analysis),
        ),
      );
      return;
    }

    if (result is EmptyWorkout) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Entrenamiento vacío'),
          content: const Text(
            'No has completado ninguna serie con repeticiones. Puedes seguir entrenando o descartar la sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard == true) {
        await ref.read(activeWorkoutProvider.notifier).cancelWorkout();
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo finalizar el entrenamiento. Tus datos permanecen abiertos para volver a intentarlo.',
        ),
      ),
    );
  }

  Future<void> _cancelWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar entrenamiento'),
        content: const Text(
          'Se eliminará el entrenamiento activo sin guardarlo en tu historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(activeWorkoutProvider.notifier).cancelWorkout();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercise() async {
    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerPageWeb()),
    );
    if (selected == null || !mounted) return;

    ref.read(activeWorkoutProvider.notifier).addExercise(selected);
    final count =
        ref.read(activeWorkoutProvider).session?.exercises.length ?? 0;
    if (count > 0) setState(() => _selectedExercise = count - 1);
  }

  void _moveExercise(int index, int direction, int count) {
    if (direction < 0 && index > 0) {
      ref
          .read(activeWorkoutProvider.notifier)
          .reorderExercises(index, index - 1);
      setState(() => _selectedExercise = index - 1);
    } else if (direction > 0 && index < count - 1) {
      ref
          .read(activeWorkoutProvider.notifier)
          .reorderExercises(index, index + 2);
      setState(() => _selectedExercise = index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeWorkoutProvider);
    final session = state.session;
    final settings = ref.watch(settingsProvider);
    final elapsed =
        ref.watch(workoutTimerProvider).value ?? state.globalTimerSeconds;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Entrenamiento')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fitness_center,
                size: 54,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text('No hay un entrenamiento activo.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver a rutinas'),
              ),
            ],
          ),
        ),
      );
    }

    if (session.exercises.isNotEmpty &&
        _selectedExercise >= session.exercises.length) {
      _selectedExercise = session.exercises.length - 1;
    }

    final currentIndex = session.exercises.indexWhere((e) => !e.completed);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.routineDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatTime(elapsed),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _focusMode ? 'Salir del modo enfoque' : 'Modo enfoque',
            onPressed:
                session.exercises.isEmpty ? null : () => _toggleFocus(session),
            icon: Icon(
              _focusMode
                  ? Icons.view_agenda_outlined
                  : Icons.center_focus_strong_outlined,
              color: _focusMode ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'Calculadora de discos',
            onPressed: () => BarbellCalculatorDialogWeb.show(context),
            icon: const Icon(
              Icons.calculate_outlined,
              color: AppColors.primary,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'discard') _cancelWorkout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'discard',
                child: Text('Descartar entrenamiento'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              tooltip: 'Finalizar entrenamiento',
              onPressed: _finishing ? null : _finishWorkout,
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isResting)
              _RestBanner(
                seconds: state.restTimerSeconds,
                format: _formatTime,
                onSkip: () =>
                    ref.read(activeWorkoutProvider.notifier).skipRest(),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (session.exercises.isEmpty) {
                    return _EmptyWorkoutExercises(
                      onAddExercise: _addExercise,
                    );
                  }

                  if (_focusMode) {
                    return _FocusWorkoutPanel(
                      session: session,
                      selectedIndex: _selectedExercise,
                      settings: settings,
                      onPrevious: _selectedExercise > 0
                          ? () => setState(() => _selectedExercise--)
                          : null,
                      onNext: _selectedExercise < session.exercises.length - 1
                          ? () => setState(() => _selectedExercise++)
                          : null,
                    );
                  }

                  if (constraints.maxWidth < 760) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                      itemCount: session.exercises.length + 1,
                      itemBuilder: (context, index) {
                        if (index == session.exercises.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 18),
                            child: OutlinedButton.icon(
                              onPressed: _addExercise,
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir ejercicio'),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MobileExerciseCard(
                            exerciseIndex: index,
                            exercise: session.exercises[index],
                            settings: settings,
                            isCurrent: index == currentIndex ||
                                (currentIndex == -1 &&
                                    index == session.exercises.length - 1),
                            totalExercises: session.exercises.length,
                            onMoveUp: index > 0
                                ? () => _moveExercise(
                                      index,
                                      -1,
                                      session.exercises.length,
                                    )
                                : null,
                            onMoveDown: index < session.exercises.length - 1
                                ? () => _moveExercise(
                                      index,
                                      1,
                                      session.exercises.length,
                                    )
                                : null,
                          ),
                        );
                      },
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: constraints.maxWidth < 1000 ? 270 : 330,
                        child: _ExerciseNavigation(
                          exercises: session.exercises,
                          selectedIndex: _selectedExercise,
                          onSelected: (index) =>
                              setState(() => _selectedExercise = index),
                          onAddExercise: _addExercise,
                          onMove: (index, direction) => _moveExercise(
                            index,
                            direction,
                            session.exercises.length,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 850),
                              child: _ExerciseEditor(
                                exerciseIndex: _selectedExercise,
                                exercise:
                                    session.exercises[_selectedExercise],
                                settings: settings,
                                totalExercises: session.exercises.length,
                                onMoveUp: _selectedExercise > 0
                                    ? () => _moveExercise(
                                          _selectedExercise,
                                          -1,
                                          session.exercises.length,
                                        )
                                    : null,
                                onMoveDown: _selectedExercise <
                                        session.exercises.length - 1
                                    ? () => _moveExercise(
                                          _selectedExercise,
                                          1,
                                          session.exercises.length,
                                        )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusWorkoutPanel extends StatelessWidget {
  final WorkoutSession session;
  final int selectedIndex;
  final SettingsState settings;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _FocusWorkoutPanel({
    required this.session,
    required this.selectedIndex,
    required this.settings,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = session.exercises[selectedIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      tooltip: 'Ejercicio anterior',
                      onPressed: onPrevious,
                      icon: const Icon(Icons.chevron_left),
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
                            '${selectedIndex + 1} de ${session.exercises.length}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ejercicio siguiente',
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ExerciseEditor(
                exerciseIndex: selectedIndex,
                exercise: exercise,
                settings: settings,
                totalExercises: session.exercises.length,
                onMoveUp: null,
                onMoveDown: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkoutExercises extends StatelessWidget {
  final VoidCallback onAddExercise;

  const _EmptyWorkoutExercises({required this.onAddExercise});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_task,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Añade un ejercicio para comenzar',
              style: AppTypography.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  final int seconds;
  final String Function(int) format;
  final VoidCallback onSkip;

  const _RestBanner({
    required this.seconds,
    required this.format,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Descanso ${format(seconds)}',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onSkip, child: const Text('Omitir')),
        ],
      ),
    );
  }
}

class _MobileExerciseCard extends StatefulWidget {
  final int exerciseIndex;
  final WorkoutExercise exercise;
  final SettingsState settings;
  final bool isCurrent;
  final int totalExercises;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _MobileExerciseCard({
    required this.exerciseIndex,
    required this.exercise,
    required this.settings,
    required this.isCurrent,
    required this.totalExercises,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_MobileExerciseCard> createState() => _MobileExerciseCardState();
}

class _MobileExerciseCardState extends State<_MobileExerciseCard> {
  bool? _manualExpanded;

  @override
  void didUpdateWidget(covariant _MobileExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.exercise.completed && widget.exercise.completed) {
      _manualExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.exercise.completed;
    final expanded =
        _manualExpanded ?? (widget.isCurrent && !widget.exercise.completed);
    final working = widget.exercise.sets
        .where((set) => set.setType == WorkoutSetType.working)
        .toList();
    final doneWorking = working.where((set) => set.completed).length;
    final leftDone =
        widget.exercise.sets.where((set) => set.leftCompleted).length;
    final rightDone =
        widget.exercise.sets.where((set) => set.rightCompleted).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: expanded ? AppColors.surface : AppColors.surfaceHigh,
        borderRadius: AppRadius.lg_,
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.32)
              : widget.isCurrent
                  ? AppColors.primary.withValues(alpha: 0.32)
                  : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: AppRadius.lg_,
            onTap: () => setState(() => _manualExpanded = !expanded),
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
                      completed ? Icons.check : Icons.fitness_center,
                      color: completed
                          ? AppColors.success
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
                          widget.exercise.exerciseNameSnapshot,
                          style: AppTypography.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (widget.exercise.unilateral)
                          Text(
                            '${widget.exercise.unilateralTarget.label} · I $leftDone/${widget.exercise.sets.length} · D $rightDone/${widget.exercise.sets.length}',
                            style: AppTypography.bodySmall.copyWith(
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          )
                        else
                          Text(
                            '$doneWorking/${working.length} series de trabajo${completed ? ' · Completado' : ''}',
                            style: AppTypography.bodySmall.copyWith(
                              color: completed
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _ExerciseEditor(
                exerciseIndex: widget.exerciseIndex,
                exercise: widget.exercise,
                settings: widget.settings,
                totalExercises: widget.totalExercises,
                onMoveUp: widget.onMoveUp,
                onMoveDown: widget.onMoveDown,
                embedded: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseNavigation extends StatelessWidget {
  final List<WorkoutExercise> exercises;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAddExercise;
  final void Function(int index, int direction) onMove;

  const _ExerciseNavigation({
    required this.exercises,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAddExercise,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            itemCount: exercises.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final completed = exercise.completed;
              final leftDone =
                  exercise.sets.where((set) => set.leftCompleted).length;
              final rightDone =
                  exercise.sets.where((set) => set.rightCompleted).length;
              return Material(
                color: index == selectedIndex
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: AppRadius.md_,
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: AppRadius.md_,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                    child: Row(
                      children: [
                        Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: completed
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.exerciseNameSnapshot,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                exercise.unilateral
                                    ? 'I $leftDone/${exercise.sets.length} · D $rightDone/${exercise.sets.length}'
                                    : '${exercise.sets.where((set) => set.completed).length}/${exercise.sets.length} series',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Subir ejercicio',
                                onPressed: index > 0
                                    ? () => onMove(index, -1)
                                    : null,
                                icon: const Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 18,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Bajar ejercicio',
                                onPressed: index < exercises.length - 1
                                    ? () => onMove(index, 1)
                                    : null,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseEditor extends ConsumerWidget {
  final int exerciseIndex;
  final WorkoutExercise exercise;
  final SettingsState settings;
  final int totalExercises;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool embedded;

  const _ExerciseEditor({
    required this.exerciseIndex,
    required this.exercise,
    required this.settings,
    required this.totalExercises,
    required this.onMoveUp,
    required this.onMoveDown,
    this.embedded = false,
  });

  WorkoutExercise? _previousExercise(WorkoutSession? previousSession) {
    if (previousSession == null) return null;
    for (final item in previousSession.exercises) {
      if (item.exerciseId == exercise.exerciseId) return item;
    }
    return null;
  }

  Future<void> _configureUnilateral(BuildContext context, WidgetRef ref) async {
    bool unilateral = exercise.unilateral;
    UnilateralTarget target = exercise.unilateralTarget;
    final result = await showDialog<(bool, UnilateralTarget)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registro unilateral'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Separar izquierda y derecha'),
                  subtitle: const Text(
                    'Cada serie se completa cuando ambos lados estén marcados.',
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
    if (result == null) return;
    ref.read(activeWorkoutProvider.notifier).configureExerciseUnilateral(
          exerciseIndex,
          unilateral: result.$1,
          target: result.$2,
        );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: exercise.notes);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota del ejercicio'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Ej.: cuidar técnica, agarre, dolor, ajuste del banco...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) {
      ref
          .read(activeWorkoutProvider.notifier)
          .updateExerciseNotes(exerciseIndex, controller.text);
    }
    controller.dispose();
  }

  Future<void> _replaceExercise(BuildContext context, WidgetRef ref) async {
    final hasCompletedWork = exercise.sets.any(
      (set) => set.completed || set.leftCompleted || set.rightCompleted,
    );
    if (hasCompletedWork) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes sustituir este ejercicio después de completar series. Añade otro ejercicio para mantener el historial correcto.',
          ),
        ),
      );
      return;
    }

    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerPageWeb()),
    );
    if (selected == null || selected.id == exercise.exerciseId) return;

    final replaced = ref
        .read(activeWorkoutProvider.notifier)
        .replaceExercise(exerciseIndex, selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          replaced
              ? 'Ejercicio sustituido por ${selected.name}.'
              : 'No se pudo sustituir porque ya existe trabajo completado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(activeWorkoutSuggestionsProvider);
    final previousSession = ref.watch(activeWorkoutPreviousSessionProvider);
    final suggestion = suggestions[exercise.exerciseId];
    final previous = _previousExercise(previousSession);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.exerciseNameSnapshot,
                    style: embedded
                        ? AppTypography.headlineLarge
                        : AppTypography.displaySmall,
                  ),
                  if (exercise.muscleGroupSnapshot.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      exercise.muscleGroupSnapshot,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Nota rápida',
              onPressed: () => _editNotes(context, ref),
              icon: Icon(
                Icons.edit_note_outlined,
                color: exercise.notes.trim().isNotEmpty
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            IconButton(
              tooltip: 'Sustituir ejercicio',
              onPressed: () => _replaceExercise(context, ref),
              icon: const Icon(
                Icons.swap_horiz,
                color: AppColors.textSecondary,
              ),
            ),
            IconButton(
              tooltip: exercise.unilateral
                  ? 'Unilateral: ${exercise.unilateralTarget.label}'
                  : 'Configurar unilateral',
              onPressed: () => _configureUnilateral(context, ref),
              icon: Icon(
                Icons.compare_arrows,
                color: exercise.unilateral
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            if (totalExercises > 1) ...[
              IconButton(
                tooltip: 'Subir',
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Bajar',
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ],
        ),
        if (exercise.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: AppRadius.md_,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.notes,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (exercise.unilateral) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryFaded,
              borderRadius: AppRadius.md_,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.compare_arrows,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${exercise.unilateralTarget.label}: registra cada lado por separado. Descanso entre lados: ${settings.unilateralSideRestSeconds}s; el descanso de serie sigue siendo independiente.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (suggestion != null) ...[
          const SizedBox(height: 12),
          _ProgressionReferenceCardWeb(
            suggestion: suggestion,
            unit: settings.weightUnit,
          ),
        ],
        const SizedBox(height: 16),
        ...List.generate(exercise.sets.length, (setIndex) {
          final set = exercise.sets[setIndex];
          final previousSet = previous != null && setIndex < previous.sets.length
              ? previous.sets[setIndex]
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _SetEditor(
              key: ValueKey('${exercise.exerciseId}_$setIndex'),
              exerciseIndex: exerciseIndex,
              setIndex: setIndex,
              set: set,
              previousSet: previousSet,
              weightUnit: settings.weightUnit,
              rirEnabled:
                  settings.isRirEnabled && set.setType == WorkoutSetType.working,
              canDelete: exercise.sets.length > 1,
              unilateral: exercise.unilateral,
              unilateralTarget: exercise.unilateralTarget,
            ),
          );
        }),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<WorkoutSetType>(
            onSelected: (type) => ref
                .read(activeWorkoutProvider.notifier)
                .addSet(exerciseIndex, setType: type),
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
            child: const _AddSetButton(),
          ),
        ),
      ],
    );

    if (embedded) return content;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
      ),
      child: content,
    );
  }
}

class _AddSetButton extends StatelessWidget {
  const _AddSetButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 18),
          SizedBox(width: 7),
          Text('Añadir serie'),
          SizedBox(width: 5),
          Icon(Icons.arrow_drop_down, size: 18),
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
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppColors.background == AppColors.background
            ? BorderRadius.circular(AppRadius.full)
            : AppRadius.sm_,
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

class _SetEditor extends ConsumerStatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final WorkoutSet set;
  final WorkoutSet? previousSet;
  final WeightUnit weightUnit;
  final bool rirEnabled;
  final bool canDelete;
  final bool unilateral;
  final UnilateralTarget unilateralTarget;

  const _SetEditor({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.set,
    required this.previousSet,
    required this.weightUnit,
    required this.rirEnabled,
    required this.canDelete,
    required this.unilateral,
    required this.unilateralTarget,
  });

  @override
  ConsumerState<_SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends ConsumerState<_SetEditor> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _rir;

  String _number(double value) => value == 0
      ? ''
      : (value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1));

  String _sideLabel(bool left) {
    final side = left ? WorkoutSide.left : WorkoutSide.right;
    if (!widget.set.completedForSide(side)) {
      return left ? 'Izquierda' : 'Derecha';
    }
    final weight = WeightConverter.displayWeight(
      widget.set.weightForSide(side),
      widget.weightUnit,
    );
    final reps = widget.set.repsForSide(side);
    final rir = widget.set.rirForSide(side);
    return '${side.shortLabel} ${_number(weight)} ${widget.weightUnit.label} × $reps${rir == null ? '' : ' @RIR $rir'}';
  }

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: _number(
        WeightConverter.displayWeight(widget.set.weight, widget.weightUnit),
      ),
    );
    _reps = TextEditingController(
      text: widget.set.reps == 0 ? '' : '${widget.set.reps}',
    );
    _rir = TextEditingController(
      text: widget.set.rir == null ? '' : '${widget.set.rir}',
    );
  }

  @override
  void didUpdateWidget(covariant _SetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weightUnit != widget.weightUnit) {
      _weight.text = _number(
        WeightConverter.displayWeight(widget.set.weight, widget.weightUnit),
      );
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rir.dispose();
    super.dispose();
  }

  void _update({bool? completed}) {
    final displayWeight =
        double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0;
    final canonicalWeight =
        WeightConverter.toCanonicalKg(displayWeight, widget.weightUnit);
    final reps = int.tryParse(_reps.text) ?? 0;
    final rir = int.tryParse(_rir.text);
    ref.read(activeWorkoutProvider.notifier).updateSet(
          widget.exerciseIndex,
          widget.setIndex,
          widget.set.copyWith(
            weight: canonicalWeight,
            reps: reps,
            rir: rir,
            clearRir: _rir.text.trim().isEmpty,
            completed: completed,
          ),
        );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !widget.set.completed,
      decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
      onChanged: (_) => _update(),
      onSubmitted: (_) => _update(),
    );
  }

  Widget _sideButton({required bool left}) {
    final selected = left
        ? widget.set.leftCompleted
        : widget.set.rightCompleted;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          _update();
          ref.read(activeWorkoutProvider.notifier).toggleUnilateralSide(
                widget.exerciseIndex,
                widget.setIndex,
                left: left,
              );
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? AppColors.successFaded : Colors.transparent,
          side: BorderSide(
            color: selected ? AppColors.success : AppColors.border,
          ),
          minimumSize: const Size(0, 46),
        ),
        icon: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? AppColors.success : AppColors.textSecondary,
          size: 18,
        ),
        label: Text(
          _sideLabel(left),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.set.completed;
    final previous = widget.previousSet;
    final previousText = previous == null
        ? 'Sin registro anterior'
        : '${_number(WeightConverter.displayWeight(previous.weight, widget.weightUnit))} ${widget.weightUnit.label} × ${previous.reps}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? AppColors.successFaded : AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.35)
              : widget.set.setType == WorkoutSetType.working
                  ? AppColors.border
                  : AppColors.warning.withValues(alpha: 0.22),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final weightField = _field(
            label: 'Peso (${widget.weightUnit.label})',
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixIcon: IconButton(
              tooltip: 'Calcular discos',
              onPressed: done
                  ? null
                  : () {
                      final target =
                          double.tryParse(_weight.text.replaceAll(',', '.'));
                      BarbellCalculatorDialogWeb.show(
                        context,
                        initialTargetWeight: target,
                      );
                    },
              icon: const Icon(Icons.calculate_outlined, size: 20),
            ),
          );
          final repsField = _field(
            label: 'Reps',
            controller: _reps,
            keyboardType: TextInputType.number,
          );
          final rirField = _field(
            label: 'RIR',
            controller: _rir,
            keyboardType: TextInputType.number,
          );

          final header = Row(
            children: [
              _SetTypeBadge(type: widget.set.setType),
              const SizedBox(width: 8),
              Text(
                '${widget.set.setType.label} ${widget.setIndex + 1}',
                style: AppTypography.labelLarge,
              ),
              const Spacer(),
              if (widget.canDelete)
                IconButton(
                  tooltip: 'Eliminar serie',
                  onPressed: done
                      ? null
                      : () => ref
                          .read(activeWorkoutProvider.notifier)
                          .removeSet(widget.exerciseIndex, widget.setIndex),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
            ],
          );

          final sideControls = widget.unilateral
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 9),
                    Text(
                      '${widget.unilateralTarget.label} · registra los valores y marca el lado realizado',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _sideButton(left: true),
                        const SizedBox(width: 8),
                        _sideButton(left: false),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.set.sideRestSeconds == 0
                          ? 'Sin descanso automático entre lados'
                          : 'Descanso entre lados: ${widget.set.sideRestSeconds}s',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink();

          if (constraints.maxWidth < 590) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Text(
                  'Anterior: $previousText',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                weightField,
                const SizedBox(height: 10),
                repsField,
                if (widget.rirEnabled) ...[
                  const SizedBox(height: 10),
                  rirField,
                ],
                if (widget.unilateral)
                  sideControls
                else ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _update(completed: !done),
                    style: FilledButton.styleFrom(
                      backgroundColor: done ? AppColors.success : null,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: Icon(done ? Icons.check_circle : Icons.check),
                    label: Text(done ? 'Completada' : 'Completar'),
                  ),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 115,
                    child: Text(
                      previousText,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: weightField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: repsField),
                  if (widget.rirEnabled) ...[
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: rirField),
                  ],
                  if (!widget.unilateral) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 125,
                      child: FilledButton.icon(
                        onPressed: () => _update(completed: !done),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              done ? AppColors.success : null,
                          minimumSize: const Size(0, 48),
                        ),
                        icon: Icon(
                          done ? Icons.check_circle : Icons.check,
                          size: 18,
                        ),
                        label: Text(done ? 'Hecha' : 'Completar'),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.unilateral) sideControls,
            ],
          );
        },
      ),
    );
  }
}

class _ProgressionReferenceCardWeb extends StatelessWidget {
  final ProgressionSuggestion suggestion;
  final WeightUnit unit;

  const _ProgressionReferenceCardWeb({
    required this.suggestion,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = _progressionColorWeb(suggestion);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md_,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_progressionIconWeb(suggestion), color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FitnessFormatter.progressionTitle(suggestion),
                  style: AppTypography.labelLarge.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            FitnessFormatter.progressionExplanation(suggestion),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (suggestion.type != ProgressionType.insufficientData) ...[
            const SizedBox(height: 5),
            Text(
              'Referencia: ${FitnessFormatter.formatProgressionTarget(suggestion.suggestedWeightKg, suggestion.suggestedRepsMin, suggestion.suggestedRepsMax, unit)}',
              style: AppTypography.bodyMedium.copyWith(color: color),
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
            ),
          ),
        ],
      ),
    );
  }
}

Color _progressionColorWeb(ProgressionSuggestion suggestion) {
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

IconData _progressionIconWeb(ProgressionSuggestion suggestion) {
  return switch (suggestion.type) {
    ProgressionType.increase => Icons.trending_up,
    ProgressionType.maintain => Icons.horizontal_rule_rounded,
    ProgressionType.deload => Icons.south_rounded,
    ProgressionType.insufficientData => Icons.more_horiz_rounded,
  };
}
