import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:gym_tracker/features/workout/presentation/active_workout_page.dart';

class WorkoutLauncher {
  static Future<void> launch(BuildContext context, WidgetRef ref, Routine routine) async {
    final activeState = ref.read(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final exercises = ref.read(exerciseListProvider);

    // Guard: another workout is already active
    if (activeState.isActive) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: const Text('Entrenamiento en curso',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text(
            '${activeState.routineDisplayName} ya está en progreso.\n\n¿Qué deseas hacer?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('continue'),
              child: const Text('Seguir con el actual'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard_start'),
              child: const Text('Descartar e iniciar nuevo',
                  style: TextStyle(color: AppColors.warning)),
            ),
          ],
        ),
      );
      if (choice == 'continue' || choice == null) {
        if (context.mounted && choice == 'continue') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
          );
        }
        return;
      }
      if (choice == 'discard_start') {
        await notifier.cancelWorkout();
      }
    }

    notifier.startWorkout(routine, exercises);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutPage()),
      );
    }
  }
}
