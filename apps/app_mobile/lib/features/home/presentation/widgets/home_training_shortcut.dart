import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Small contextual route back into the *existing* active workout.
/// Inicio never renders the next-workout hero or starts a new workout.
class HomeTrainingShortcut extends StatelessWidget {
  const HomeTrainingShortcut({
    super.key,
    required this.routineName,
    required this.isPendingReview,
    required this.onContinue,
  });

  final String routineName;
  final bool isPendingReview;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = isPendingReview
        ? 'Pendiente de revisar · $routineName'
        : 'Continuar · $routineName';

    return Semantics(
      button: true,
      label: isPendingReview
          ? 'Entrenamiento pendiente. Continuar $routineName'
          : 'Continuar entrenamiento $routineName',
      child: InkWell(
        key: const ValueKey('home_continue_workout'),
        onTap: onContinue,
        borderRadius: AppRadius.md_,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
