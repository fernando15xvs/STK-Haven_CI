import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/active_workout_suggestions_provider.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Compact Exercise Memory controls used by the active workout on mobile.
class ExerciseMemoryActionsCard extends ConsumerWidget {
  const ExerciseMemoryActionsCard({
    super.key,
    required this.exerciseIndex,
    required this.current,
    required this.previousAligned,
  });

  final int exerciseIndex;
  final WorkoutExercise current;
  final WorkoutExercise? previousAligned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(
      activeWorkoutExerciseMemoryProvider.select(
        (entries) => entries[current.exerciseId],
      ),
    );
    if (memory == null) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    final latest = memory.latestRepresentativeSet;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _lastPerformanceText(memory, latest, settings.weightUnit),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: previousAligned == null
                    ? null
                    : () => _useLastTime(context, ref),
                icon: const Icon(Icons.history_toggle_off, size: 17),
                label: const Text('Usar última vez'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPreviousSet(context, ref),
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copiar serie anterior'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _useLastTime(BuildContext context, WidgetRef ref) {
    final previous = previousAligned;
    if (previous == null) return;
    final applied = ref
        .read(activeWorkoutProvider.notifier)
        .applyPreviousExercise(exerciseIndex, previous);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? 'Última ejecución aplicada a las series pendientes.'
              : 'No se pudo aplicar la última ejecución.',
        ),
      ),
    );
  }

  void _copyPreviousSet(BuildContext context, WidgetRef ref) {
    for (var index = 1; index < current.sets.length; index++) {
      final target = current.sets[index];
      if (target.completed || target.leftCompleted || target.rightCompleted) {
        continue;
      }
      final copied = ref
          .read(activeWorkoutProvider.notifier)
          .copyPreviousSet(exerciseIndex, index);
      if (!copied) continue;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Serie ${index + 1} copiada.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay una serie pendiente compatible para copiar.'),
      ),
    );
  }

  static String _lastPerformanceText(
    ExercisePerformanceMemoryEntry memory,
    WorkoutSet? latest,
    WeightUnit unit,
  ) {
    final date = memory.performedAt.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final routine = memory.routineName.trim().isEmpty
        ? 'Entrenamiento libre'
        : memory.routineName.trim();

    if (latest == null) return 'Última vez: $day/$month · $routine';

    final weight = FitnessFormatter.formatWeight(latest.performanceWeight, unit);
    final rir = latest.performanceRir;
    return 'Última vez: $day/$month · $routine · $weight × ${latest.performanceReps}${rir == null ? '' : ' @RIR $rir'}';
  }
}
