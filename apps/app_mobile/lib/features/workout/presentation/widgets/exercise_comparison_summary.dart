import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class ExerciseComparisonSummary extends StatelessWidget {
  const ExerciseComparisonSummary({
    super.key,
    required this.comparison,
    required this.unit,
  });

  final ExercisePerformanceComparison comparison;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final volumeDiff = comparison.volumeDifferencePercent;
    final weightDiff = comparison.bestWeightDifference;
    final setsDiff = comparison.workingSetsDifference;
    final previousDate = comparison.previousPerformedAt.toLocal();
    final dateLabel =
        '${previousDate.day.toString().padLeft(2, '0')}/${previousDate.month.toString().padLeft(2, '0')}';
    final previousContext = comparison.previousRoutineName.trim().isEmpty
        ? 'Entrenamiento libre'
        : comparison.previousRoutineName.trim();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comparison.exerciseName,
            style: AppTypography.bodyLarge,
          ),
          const SizedBox(height: 3),
          Text(
            'Última ejecución global: $dateLabel · $previousContext',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeltaChip(
                label: 'Volumen',
                value: volumeDiff == null
                    ? 'Sin base'
                    : '${volumeDiff >= 0 ? '+' : ''}${volumeDiff.toStringAsFixed(1)}%',
              ),
              _DeltaChip(
                label: 'Mejor peso',
                value: weightDiff == 0
                    ? 'Sin cambio'
                    : '${weightDiff > 0 ? '+' : ''}${FitnessFormatter.formatWeight(weightDiff, unit)}',
              ),
              _DeltaChip(
                label: 'Series',
                value: setsDiff == 0
                    ? 'Sin cambio'
                    : '${setsDiff > 0 ? '+' : ''}$setsDiff',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${FitnessFormatter.formatVolume(comparison.previousVolume, unit)} → ${FitnessFormatter.formatVolume(comparison.currentVolume, unit)} registrados',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label · $value',
        style: AppTypography.labelSmall.copyWith(color: AppColors.info),
      ),
    );
  }
}
