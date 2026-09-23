import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';

import '../app_colors.dart';

class PrimaryButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  Future<void> _handlePress(BuildContext context, WidgetRef ref) async {
    final callback = onPressed;
    if (callback == null) return;

    if (label.toLowerCase() == 'finalizar') {
      final session = ref.read(activeWorkoutProvider).session;
      if (session != null) {
        final completedAnySet = session.exercises.any(
          (exercise) => exercise.sets.any(
            (set) => set.completed && set.reps > 0,
          ),
        );
        final incompleteExercises = session.exercises.where((exercise) {
          return exercise.sets.isEmpty ||
              exercise.sets.any((set) => !set.completed);
        }).length;

        if (completedAnySet && incompleteExercises > 0) {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppColors.surfaceHigh,
              title: Text(
                'Aún faltan ejercicios',
                style: AppTypography.headlineMedium,
              ),
              content: Text(
                'Te faltan $incompleteExercises de ${session.exercises.length} '
                'ejercicios por completar. Si finalizas ahora, se guardará '
                'solo lo que ya completaste. ¿Seguro que deseas finalizar?',
                style: AppTypography.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Seguir entrenando',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    'Finalizar de todos modos',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }
      }
    }

    callback();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading || onPressed == null
            ? null
            : () => _handlePress(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceBorder,
          disabledForegroundColor: AppColors.textDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.labelLarge.copyWith(
                      color: onPressed == null
                          ? AppColors.textDisabled
                          : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
