import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Presents recorded vs unperformed historical sets without inventing failure.
class ExerciseHistorySetRow extends StatelessWidget {
  final WorkoutSet set;
  final WeightUnit weightUnit;

  const ExerciseHistorySetRow({
    super.key,
    required this.set,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final value =
        '${FitnessFormatter.formatWeight(set.weight, weightUnit)} × ${set.reps}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Flexible(
            child: Text(
              value,
              key: const ValueKey('history_set_value'),
              style: AppTypography.monoMedium.copyWith(
                color: set.completed
                    ? palette.textPrimary
                    : palette.textSecondary,
                // A pending set was not necessarily attempted or failed.
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!set.completed) ...[
            const SizedBox(width: AppSpacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: AppRadius.sm_,
                border: Border.all(color: palette.surfaceBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                child: Text(
                  'Pendiente',
                  key: const ValueKey('history_set_pending'),
                  style: AppTypography.labelMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
