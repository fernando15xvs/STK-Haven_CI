import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_set_record_status.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Presents recorded vs unperformed historical sets without inventing failure.
class ExerciseHistorySetRow extends StatelessWidget {
  final WorkoutSet set;
  final WeightUnit weightUnit;
  /// Only supply when the set has an explicitly recorded skip/failure action.
  /// A historical false `completed` value does NOT provide that evidence.
  final WorkoutSetOutcomeEvidence? recordedOutcome;

  const ExerciseHistorySetRow({
    super.key,
    required this.set,
    required this.weightUnit,
    this.recordedOutcome,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final status = WorkoutSetRecordStatusPolicy.fromSet(
      set,
      recordedOutcome: recordedOutcome,
    );
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
          if (status != WorkoutSetRecordStatus.completed) ...[
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
                  status.label,
                  key: ValueKey('history_set_status_${status.name}'),
                  style: AppTypography.labelMedium.copyWith(
                    color: switch (status) {
                      WorkoutSetRecordStatus.skipped => palette.warning,
                      WorkoutSetRecordStatus.failed => palette.error,
                      _ => palette.textSecondary,
                    },
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
