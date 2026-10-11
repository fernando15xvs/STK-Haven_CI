import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immediate feedback when a completed working set exceeds its rep target.
/// The message is informational; it does not auto-change prescribed loads.
class ExerciseRepRangeNotice extends ConsumerWidget {
  final String exerciseId;
  const ExerciseRepRangeNotice({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeWorkoutProvider.select((s) => s.session));
    if (session == null || session.routineId == null) {
      return const SizedBox.shrink();
    }
    final routine = ref.watch(routineRepositoryProvider).getAllRoutines()
        .where((r) => r.id == session.routineId).firstOrNull;
    final target = routine?.exercises
        .where((item) => item.exerciseId == exerciseId).firstOrNull;
    final exercise = session.exercises
        .where((item) => item.exerciseId == exerciseId).firstOrNull;
    if (target == null || exercise == null) return const SizedBox.shrink();

    final above = exercise.sets.where((s) =>
        s.setType == WorkoutSetType.working &&
        s.completed && s.performanceReps > target.targetRepsMax);
    if (above.isEmpty) return const SizedBox.shrink();

    final reps = above.map((s) => s.performanceReps)
        .reduce((a, b) => a > b ? a : b);
    final settings = ref.watch(settingsProvider);
    final jump = WeightConverter.displayWeight(
        settings.incrementForExercise(exerciseId), settings.weightUnit);
    final label = jump.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.trending_up),
        title: Text('$reps reps superan tu objetivo '
            'de ${target.targetRepsMin}–${target.targetRepsMax}'),
        subtitle: Text(
          'Revisa tu progresión: el salto configurado es '
          '$label ${settings.weightUnit.label}. '
          'No aumentes automáticamente por una sola serie; '
          'confirma técnica, RIR y el resto de series.',
        ),
      ),
    );
  }
}
