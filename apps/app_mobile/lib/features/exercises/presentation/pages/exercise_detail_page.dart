import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';

class ExerciseDetailPage extends ConsumerWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final allPRs = ref.watch(personalRecordRepositoryProvider).getAllPRs();
    final history = ref.watch(workoutHistoryProvider);
    final trend = ExerciseProgressCalculator.calculateTrend(history, exercise.id);
    
    // Find PRs specific to this exercise
    final maxWeightPR = allPRs.where((p) => p.exerciseId == exercise.id && p.type == PRType.maxWeight).fold<PersonalRecordEvent?>(null, (prev, element) => prev == null || element.newValue > prev.newValue ? element : prev);
    final bestSetVolumePR = allPRs.where((p) => p.exerciseId == exercise.id && p.type == PRType.bestSetVolume).fold<PersonalRecordEvent?>(null, (prev, element) => prev == null || element.newValue > prev.newValue ? element : prev);

    // Get History for this exercise
    final sessionsWithExercise = history.where((s) => s.exercises.any((e) => e.exerciseId == exercise.id)).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt)); // latest first

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name.toUpperCase(), style: AppTypography.headlineMedium),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        children: [
          // Basic Info Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(Icons.fitness_center, 'Músculo', exercise.muscleGroup),
              if (exercise.secondaryMuscles.isNotEmpty)
                _buildPill(Icons.group_work, 'Secundarios', exercise.secondaryMuscles.join(', ')),
              if (exercise.equipment.isNotEmpty)
                _buildPill(Icons.build, 'Equipo', exercise.equipment),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Progress Section
          Text('TU PROGRESO', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.md),
          if (trend.current1RM > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('1RM ESTIMADO', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              WeightConverter.formatWeight(trend.current1RM, settings.weightUnit), 
                              style: AppTypography.displaySmall.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      if (trend.percentChange30Days != null && trend.percentChange30Days != 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: trend.percentChange30Days! >= 0 ? AppColors.successFaded : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: AppRadius.sm_,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('ÚLTIMOS 30 DÍAS', style: AppTypography.labelSmall.copyWith(color: trend.percentChange30Days! >= 0 ? AppColors.success : AppColors.error, fontSize: 8)),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    trend.percentChange30Days! >= 0 ? Icons.trending_up : Icons.trending_down,
                                    color: trend.percentChange30Days! >= 0 ? AppColors.success : AppColors.error,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${trend.percentChange30Days! > 0 ? '+' : ''}${WeightConverter.formatWeight(trend.absoluteChange30Days!, settings.weightUnit)}',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: trend.percentChange30Days! >= 0 ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClipRect(
                    child: _OneRMChart(data: trend.history1RM, weightUnit: settings.weightUnit),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Center(
                child: Text('Sin datos de 1RM estimado', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.xxl),

          // PRs Section
          Text('RÉCORDS', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.md),
          if (maxWeightPR == null && bestSetVolumePR == null)
            const Text('Aún no tienes récords', style: TextStyle(color: AppColors.textSecondary))
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  if (maxWeightPR != null)
                    _buildTrophyRow(
                      'Mayor peso',
                      FitnessFormatter.formatPRValue(maxWeightPR.newValue, PRType.maxWeight, settings.weightUnit),
                      Icons.fitness_center,
                      isLast: bestSetVolumePR == null,
                    ),
                  if (bestSetVolumePR != null)
                    _buildTrophyRow(
                      'Mejor serie (volumen)',
                      FitnessFormatter.formatPRValue(bestSetVolumePR.newValue, PRType.bestSetVolume, settings.weightUnit),
                      Icons.layers,
                      isLast: true,
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),

          // History Section
          Text('HISTORIAL RECIENTE', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.md),
          if (sessionsWithExercise.isEmpty)
            const Text('Aún no has realizado este ejercicio', style: TextStyle(color: AppColors.textSecondary))
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: sessionsWithExercise.take(5).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final session = entry.value;
                  final exData = session.exercises.firstWhere((e) => e.exerciseId == exercise.id);
                  final isLast = idx == (sessionsWithExercise.take(5).length - 1);
                  
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBorder,
                                borderRadius: AppRadius.sm_,
                              ),
                              child: Text(
                                DateFormat('dd MMM', 'es').format(session.startedAt).toUpperCase(),
                                style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: exData.sets.map((set) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${FitnessFormatter.formatWeight(set.weight, settings.weightUnit)} × ${set.reps}',
                                          style: AppTypography.monoMedium.copyWith(
                                            color: set.completed ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.5),
                                            decoration: set.completed ? null : TextDecoration.lineThrough,
                                          ),
                                        ),
                                        if (!set.completed) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                            child: Text('Fallida', style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontSize: 9)),
                                          ),
                                        ]
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: AppColors.surfaceBorder),
                    ],
                  );
                }).toList(),
              ),
            ),
            
          const SizedBox(height: AppSpacing.xxl),

          // Technique Section
          if (exercise.instructions.isNotEmpty) ...[
            Text('TÉCNICA', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Text(exercise.instructions, style: AppTypography.bodyMedium.copyWith(height: 1.6)),
            ),
            const SizedBox(height: 40),
          ]
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$label:', style: AppTypography.labelSmall),
          const SizedBox(width: 4),
          Text(value, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrophyRow(String title, String value, IconData icon, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: AppRadius.sm_,
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          title: Text(title, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          trailing: Text(value, style: AppTypography.headlineSmall),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 64, color: AppColors.surfaceBorder),
      ],
    );
  }
}

class _OneRMChart extends StatelessWidget {
  final List<ExerciseProgressPoint> data;
  final WeightUnit weightUnit;

  const _OneRMChart({required this.data, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Registra al menos 2 entrenamientos para ver la gráfica', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final minY = data.map((e) => e.value).reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.1;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppColors.surfaceHigh,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} ${weightUnit.label}',
                    const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceBorder,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  final idx = value.toInt();
                  if (idx >= 0 && idx < data.length) {
                    final date = data[idx].date;
                    // Only show first and last to avoid clutter
                    if (idx == 0 || idx == data.length - 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('dd MMM', 'es').format(date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: -0.2, // Adds breathing room so dots aren't cut off
          maxX: (data.length - 1).toDouble() + 0.2, // Adds breathing room
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), WeightConverter.displayWeight(e.value.value, weightUnit))).toList(),
              isCurved: true,
              curveSmoothness: 0.1,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.surfaceHigh,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
                cutOffY: minY,
                applyCutOffY: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
