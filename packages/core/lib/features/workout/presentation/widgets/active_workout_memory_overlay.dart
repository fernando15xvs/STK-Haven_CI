import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/fitness_math.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/active_workout_suggestions_provider.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/presentation/widgets/quick_set_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gives each exercise a direct entry into its own previous-performance tools.
/// Memory never floats over set inputs or the permanent Finish action.
class ActiveWorkoutMemoryAccess extends InheritedWidget {
  const ActiveWorkoutMemoryAccess({
    super.key,
    required this.openForExercise,
    required super.child,
  });

  final void Function(String instanceId) openForExercise;

  static ActiveWorkoutMemoryAccess? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActiveWorkoutMemoryAccess>();

  @override
  bool updateShouldNotify(ActiveWorkoutMemoryAccess oldWidget) =>
      openForExercise != oldWidget.openForExercise;
}

/// Route boundary for contextual exercise memory and quick-entry actions.
class ActiveWorkoutMemoryOverlay extends ConsumerStatefulWidget {
  const ActiveWorkoutMemoryOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ActiveWorkoutMemoryOverlay> createState() =>
      _ActiveWorkoutMemoryOverlayState();
}

class _ActiveWorkoutMemoryOverlayState
    extends ConsumerState<ActiveWorkoutMemoryOverlay> {
  String? _oneRmMessage;
  String? _oneRmExerciseId;

  /// A modal sheet keeps memory tools reachable without a floating panel
  /// covering the rest countdown, set inputs or the Finish action.
  Future<void> _openCompactMemory(String requestedInstanceId) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) => Consumer(
          builder: (sheetContext, sheetRef, _) {
            final session = sheetRef.watch(
              activeWorkoutProvider.select((state) => state.session),
            );
            if (session == null || session.exercises.isEmpty) {
              return const SizedBox.shrink();
            }
            // Resolve by stable instance id, not by mutable list index.
            // Reordering exercises while a sheet is open cannot show memory
            // for a different exercise.
            var exerciseIndex = session.exercises.indexWhere(
              (item) => item.instanceId == requestedInstanceId,
            );
            if (exerciseIndex < 0) {
              exerciseIndex = session.exercises.indexWhere(
                (item) => !item.completed,
              );
            }
            if (exerciseIndex < 0) {
              exerciseIndex = session.exercises.length - 1;
            }
            final exercise = session.exercises[exerciseIndex];
            final memory = sheetRef.watch(
              activeWorkoutExerciseMemoryProvider.select(
                (items) => items[exercise.exerciseId],
              ),
            );
            final previousSession = sheetRef.watch(
              activeWorkoutPreviousSessionProvider,
            );
            final previousAligned = _findExercise(
              previousSession,
              exercise.exerciseId,
            );
            final settings = sheetRef.watch(settingsProvider);
            final canUndo = sheetRef.watch(
              activeWorkoutProvider.select((state) => state.canUndo),
            );
            final recommendedSide = exercise.unilateral
                ? _recommendedSide(sheetRef, exerciseIndex, exercise)
                : null;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Memoria del ejercicio',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar memoria',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    _buildPanel(
                      sheetContext,
                      exerciseIndex: exerciseIndex,
                      exercise: exercise,
                      memory: memory,
                      previousAligned: previousAligned,
                      settings: settings,
                      recommendedSide: recommendedSide,
                      canUndo: canUndo,
                      visibleOneRmMessage:
                          _oneRmExerciseId == exercise.exerciseId
                              ? _oneRmMessage
                              : null,
                      onRefresh: () => refreshSheet(() {}),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The contextual launcher lives in each exercise header, inside normal
    // layout flow. The sheet still supports previous sets, 1RM, quick entry
    // and undo without obscuring table cells or the Finish button.
    return ActiveWorkoutMemoryAccess(
      openForExercise: (instanceId) {
        FocusManager.instance.primaryFocus?.unfocus();
        _openCompactMemory(instanceId);
      },
      child: widget.child,
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required int exerciseIndex,
    required WorkoutExercise exercise,
    required ExercisePerformanceMemoryEntry? memory,
    required WorkoutExercise? previousAligned,
    required SettingsState settings,
    required WorkoutSide? recommendedSide,
    required bool canUndo,
    required String? visibleOneRmMessage,
    VoidCallback? onRefresh,
  }) {
    return Material(
      elevation: settings.performanceMode == PerformanceMode.savings ? 0 : 8,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (memory != null) ...[
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _memoryLabel(memory, settings.weightUnit),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (recommendedSide != null)
                          Text(
                            'Lado inicial: ${recommendedSide.label}${settings.unilateralSameWeightByDefault ? ' · mismo peso' : ''}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Usar última vez',
                    onPressed: previousAligned == null
                        ? null
                        : () => ref
                            .read(activeWorkoutProvider.notifier)
                            .applyPreviousExercise(
                              exerciseIndex,
                              previousAligned,
                            ),
                    icon: const Icon(Icons.history_toggle_off),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copiar serie anterior',
                    onPressed: () => _copyFirstPending(
                      ref,
                      exerciseIndex,
                      exercise,
                    ),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      exercise.exerciseNameSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Entrada rápida peso → reps → RIR',
                  onPressed: exercise.completed
                      ? null
                      : () => QuickSetEntryDialog.show(
                            context,
                            ref,
                            exerciseIndex: exerciseIndex,
                            exercise: exercise,
                            settings: settings,
                          ),
                  icon: const Icon(Icons.keyboard_alt_outlined),
                ),
                Semantics(
                  button: true,
                  label: '1RM del ejercicio activo',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final message = _oneRmResult(
                        exercise,
                        memory,
                        settings.weightUnit,
                      );
                      setState(() {
                        _oneRmExerciseId = exercise.exerciseId;
                        _oneRmMessage = message;
                      });
                      onRefresh?.call();
                    },
                    icon: const Icon(Icons.calculate_outlined),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Deshacer última acción',
                  onPressed: canUndo
                      ? () => ref
                          .read(activeWorkoutProvider.notifier)
                          .undoLastAction()
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                ),

              ],
            ),
            if (visibleOneRmMessage != null) ...[
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: 17,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      visibleOneRmMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _oneRmMessage = null;
                        _oneRmExerciseId = null;
                      });
                      onRefresh?.call();
                    },
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _oneRmResult(
    WorkoutExercise exercise,
    ExercisePerformanceMemoryEntry? memory,
    WeightUnit unit,
  ) {
    WorkoutSet? reference;

    for (final set in exercise.sets) {
      if (set.setType == WorkoutSetType.working &&
          set.performanceWeight > 0 &&
          set.performanceReps > 0 &&
          !set.completed) {
        reference = set;
        break;
      }
    }
    if (reference == null) {
      for (final set in exercise.sets.reversed) {
        if (set.setType == WorkoutSetType.working &&
            set.completed &&
            set.performanceWeight > 0 &&
            set.performanceReps > 0) {
          reference = set;
          break;
        }
      }
    }
    reference ??= memory?.latestRepresentativeSet;

    final weight = reference?.performanceWeight ?? 0;
    final reps = reference?.performanceReps ?? 0;
    final estimate = FitnessMath.estimated1RM(weight, reps);

    if (reference == null || weight <= 0 || reps <= 0) {
      return 'Ingresa peso y repeticiones en una serie de trabajo para estimar el 1RM.';
    }

    final referenceText =
        '${FitnessFormatter.formatWeight(weight, unit)} × $reps${reference.performanceRir == null ? '' : ' @RIR ${reference.performanceRir}'}';
    final estimateText = estimate == null
        ? 'Sin estimación válida para $reps repeticiones.'
        : '1RM estimado: ${FitnessFormatter.formatWeight(estimate, unit)}';
    return 'Referencia: $referenceText · $estimateText';
  }

  static WorkoutSide? _recommendedSide(
    WidgetRef ref,
    int exerciseIndex,
    WorkoutExercise exercise,
  ) {
    for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      if (!exercise.sets[setIndex].completed) {
        return ref
            .read(activeWorkoutProvider.notifier)
            .recommendedUnilateralFirstSide(exerciseIndex, setIndex);
      }
    }
    return null;
  }

  static WorkoutExercise? _findExercise(
    WorkoutSession? session,
    String exerciseId,
  ) {
    if (session == null) return null;
    for (final exercise in session.exercises) {
      if (exercise.exerciseId == exerciseId) return exercise;
    }
    return null;
  }

  static void _copyFirstPending(
    WidgetRef ref,
    int exerciseIndex,
    WorkoutExercise exercise,
  ) {
    for (var index = 1; index < exercise.sets.length; index++) {
      final set = exercise.sets[index];
      if (set.completed || set.leftCompleted || set.rightCompleted) continue;
      if (ref
          .read(activeWorkoutProvider.notifier)
          .copyPreviousSet(exerciseIndex, index)) {
        return;
      }
    }
  }

  static String _memoryLabel(
    ExercisePerformanceMemoryEntry entry,
    WeightUnit unit,
  ) {
    final latest = entry.latestRepresentativeSet;
    final date = entry.performedAt.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final routine = entry.routineName.trim().isEmpty
        ? 'Entrenamiento libre'
        : entry.routineName.trim();
    if (latest == null) return 'Última vez $day/$month · $routine';

    final weight = FitnessFormatter.formatWeight(latest.performanceWeight, unit);
    final rir = latest.performanceRir;
    return 'Última vez $day/$month · $routine · $weight × ${latest.performanceReps}${rir == null ? '' : ' @RIR $rir'}';
  }
}
