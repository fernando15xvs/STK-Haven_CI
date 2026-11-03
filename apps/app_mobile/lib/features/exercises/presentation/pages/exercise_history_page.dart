import 'package:core/domain/models/exercise.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_history_set_row.dart';
import 'package:intl/intl.dart';

/// Complete, read-only history for one exercise. Unlike the five-row
/// previews, this renders every matching session, including partial sets.
class ExerciseHistoryPage extends ConsumerWidget {
  const ExerciseHistoryPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightUnit = ref.watch(settingsProvider).weightUnit;
    final sessions = ref
        .watch(workoutHistoryProvider)
        .where(
          (session) => session.exercises.any(
            (item) => item.exerciseId == exercise.id,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historial · ${exercise.name}',
          style: AppTypography.headlineSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Aún no hay sesiones registradas para este ejercicio.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: sessions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.md,
                    ),
                    child: Text(
                      '${sessions.length} sesiones registradas',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  );
                }
                final session = sessions[index - 1];
                final matchingExercises = session.exercises
                    .where((item) => item.exerciseId == exercise.id)
                    .toList(growable: false);
                final hasSets =
                    matchingExercises.any((item) => item.sets.isNotEmpty);

                return Card(
                  key: ValueKey('exercise_history_${session.id}'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  color: AppColors.of(context).surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.routineNameSnapshot.isEmpty
                              ? 'Entrenamiento libre'
                              : session.routineNameSnapshot,
                          style: AppTypography.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          DateFormat('dd MMM yyyy', 'es')
                              .format(session.startedAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.of(context).textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (!hasSets)
                          Text(
                            'Sin series registradas',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.of(context).textSecondary,
                            ),
                          )
                        else
                          for (final item in matchingExercises)
                            for (final set in item.sets)
                              ExerciseHistorySetRow(
                                set: set,
                                weightUnit: weightUnit,
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
