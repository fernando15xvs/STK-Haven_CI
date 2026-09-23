import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/progress/application/muscle_workload_calculator.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';

class MuscleHeatmapGrid extends ConsumerWidget {
  const MuscleHeatmapGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timeFilterProvider);
    final history = ref.watch(workoutHistoryProvider);
    
    final sessions = history.where((s) => s.finishedAt.isAfter(filter.startDate)).toList();
    final workload = MuscleWorkloadCalculator.calculate(sessions);
    
    if (workload.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'Aún no hay suficiente historial',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Completa entrenamientos para ver tu mapa muscular.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by most trained muscle
    final sortedMuscles = workload.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    final maxSets = sortedMuscles.first.value;
    final totalSets = workload.values.fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        Text('MÚSCULOS', style: AppTypography.labelLarge),
        const SizedBox(height: 4),
        Text('ÚLTIMOS ${filter.label}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.lg),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: sortedMuscles.length,
          itemBuilder: (context, index) {
            final entry = sortedMuscles[index];
            final muscle = entry.key;
            final sets = entry.value;
            final percentOfMax = sets / maxSets;
            final percentOfTotal = (sets / totalSets) * 100;
            
            // Color interpolation based on intensity
            final intensityColor = Color.lerp(AppColors.surfaceHigh, AppColors.primary, percentOfMax * 0.8) ?? AppColors.surfaceHigh;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: intensityColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(muscle.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percentOfMax,
                      backgroundColor: AppColors.surfaceHigh.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(intensityColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${sets.toInt()} series', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${percentOfTotal.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
