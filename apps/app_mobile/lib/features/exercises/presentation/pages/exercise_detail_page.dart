import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_demonstration_card.dart';
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
    final definition = CuratedExerciseCatalog.byId[exercise.id];
    final profile = CuratedExerciseCatalog.anatomyFor(exercise.id);
    final emphasis = profile == null
        ? <String>[]
        : [
            for (final id in profile.emphasisIds)
              if (MuscleTaxonomyV1.byId[id] != null)
                MuscleTaxonomyV1.byId[id]!.labelEs,
          ];
    final settings = ref.watch(settingsProvider);
    final allPRs = ref.watch(personalRecordRepositoryProvider).getAllPRs();
    final history = ref.watch(workoutHistoryProvider);
    final trend = ExerciseProgressCalculator.calculateTrend(
      history,
      exercise.id,
    );

    // Find PRs specific to this exercise
    final maxWeightPR = allPRs
        .where((p) => p.exerciseId == exercise.id && p.type == PRType.maxWeight)
        .fold<PersonalRecordEvent?>(
          null,
          (prev, element) =>
              prev == null || element.newValue > prev.newValue ? element : prev,
        );
    final bestSetVolumePR = allPRs
        .where(
          (p) => p.exerciseId == exercise.id && p.type == PRType.bestSetVolume,
        )
        .fold<PersonalRecordEvent?>(
          null,
          (prev, element) =>
              prev == null || element.newValue > prev.newValue ? element : prev,
        );

    // Get History for this exercise
    final sessionsWithExercise =
        history
            .where((s) => s.exercises.any((e) => e.exerciseId == exercise.id))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)); // latest first

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exercise.name.toUpperCase(),
          style: AppTypography.headlineMedium,
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        children: [
          // Basic Info Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(
                context,
                Icons.fitness_center,
                'Músculo',
                exercise.muscleGroup,
              ),
              if (exercise.secondaryMuscles.isNotEmpty)
                _buildPill(
                  context,
                  Icons.group_work,
                  'Secundarios',
                  exercise.secondaryMuscles.join(', '),
                ),
              if (exercise.equipment.isNotEmpty)
                _buildPill(context, Icons.build, 'Equipo', exercise.equipment),
              if (definition != null) ...[
                _buildPill(context, Icons.tune, 'Patrón',
                    definition.movementCategory.labelEs),
                _buildPill(context, Icons.layers_outlined, 'Tipo',
                    definition.mechanics.labelEs),
                _buildPill(context, Icons.school_outlined, 'Nivel orientativo',
                    definition.difficulty),
              ],
              if (emphasis.isNotEmpty)
                _buildPill(context, Icons.track_changes_outlined,
                    'Énfasis, no aislamiento', emphasis.join(', ')),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),
          ExerciseDemonstrationCard(
            exercise: exercise,
            reduceMotion: settings.reduceMotion ||
                settings.performanceMode == PerformanceMode.savings,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Progress Section
          Text(
            'TU PROGRESO',
            style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          if (trend.current1RM > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.of(context).surfaceBorder),
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
                            Text(
                              '1RM ESTIMADO',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.of(context).textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              WeightConverter.formatWeight(
                                trend.current1RM,
                                settings.weightUnit,
                              ),
                              style: AppTypography.displaySmall.copyWith(
                                color: AppColors.of(context).primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trend.percentChange30Days != null &&
                          trend.percentChange30Days != 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: trend.percentChange30Days! >= 0
                                ? AppColors.of(context).successFaded
                                : AppColors.of(
                                    context,
                                  ).error.withValues(alpha: 0.15),
                            borderRadius: AppRadius.sm_,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ÚLTIMOS 30 DÍAS',
                                style: AppTypography.labelSmall.copyWith(
                                  color: trend.percentChange30Days! >= 0
                                      ? AppColors.of(context).success
                                      : AppColors.of(context).error,
                                  fontSize: 8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    trend.percentChange30Days! >= 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: trend.percentChange30Days! >= 0
                                        ? AppColors.of(context).success
                                        : AppColors.of(context).error,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${trend.percentChange30Days! > 0 ? '+' : ''}${WeightConverter.formatWeight(trend.absoluteChange30Days!, settings.weightUnit)}',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: trend.percentChange30Days! >= 0
                                          ? AppColors.of(context).success
                                          : AppColors.of(context).error,
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
                  _OneRMChart(
                    data: trend.history1RM,
                    weightUnit: settings.weightUnit,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.of(context).surfaceBorder),
              ),
              child: Center(
                child: Text(
                  'Sin datos de 1RM estimado',
                  style: TextStyle(color: AppColors.of(context).textSecondary),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),

          // PRs Section
          Text(
            'RÉCORDS',
            style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          if (maxWeightPR == null && bestSetVolumePR == null)
            Text(
              'Aún no tienes récords',
              style: TextStyle(color: AppColors.of(context).textSecondary),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.of(context).surfaceBorder),
              ),
              child: Column(
                children: [
                  if (maxWeightPR != null)
                    _buildTrophyRow(
                      context,
                      'Mayor peso',
                      FitnessFormatter.formatPRValue(
                        maxWeightPR.newValue,
                        PRType.maxWeight,
                        settings.weightUnit,
                      ),
                      Icons.fitness_center,
                      isLast: bestSetVolumePR == null,
                    ),
                  if (bestSetVolumePR != null)
                    _buildTrophyRow(
                      context,
                      'Mejor serie (volumen)',
                      FitnessFormatter.formatPRValue(
                        bestSetVolumePR.newValue,
                        PRType.bestSetVolume,
                        settings.weightUnit,
                      ),
                      Icons.layers,
                      isLast: true,
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),

          // History Section
          Text(
            'HISTORIAL RECIENTE',
            style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          if (sessionsWithExercise.isEmpty)
            Text(
              'Aún no has realizado este ejercicio',
              style: TextStyle(color: AppColors.of(context).textSecondary),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceHigh,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.of(context).surfaceBorder),
              ),
              child: Column(
                children: sessionsWithExercise
                    .take(5)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                      final idx = entry.key;
                      final session = entry.value;
                      final exData = session.exercises.firstWhere(
                        (e) => e.exerciseId == exercise.id,
                      );
                      final isLast =
                          idx == (sessionsWithExercise.take(5).length - 1);

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.of(context).surfaceBorder,
                                    borderRadius: AppRadius.sm_,
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd MMM',
                                      'es',
                                    ).format(session.startedAt).toUpperCase(),
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.of(
                                        context,
                                      ).textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: exData.sets.map((set) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${FitnessFormatter.formatWeight(set.weight, settings.weightUnit)} × ${set.reps}',
                                              style: AppTypography.monoMedium
                                                  .copyWith(
                                                    color: set.completed
                                                        ? AppColors.of(
                                                            context,
                                                          ).textPrimary
                                                        : AppColors.of(context)
                                                              .textSecondary
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    decoration: set.completed
                                                        ? null
                                                        : TextDecoration
                                                              .lineThrough,
                                                  ),
                                            ),
                                            if (!set.completed) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.of(context)
                                                      .error
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Fallida',
                                                  style: AppTypography
                                                      .labelSmall
                                                      .copyWith(
                                                        color: AppColors.of(
                                                          context,
                                                        ).error,
                                                        fontSize: 9,
                                                      ),
                                                ),
                                              ),
                                            ],
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
                            Divider(
                              height: 1,
                              color: AppColors.of(context).surfaceBorder,
                            ),
                        ],
                      );
                    })
                    .toList(),
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),


        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.of(context).surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.of(context).primary),
          const SizedBox(width: 6),
          Text('$label:', style: AppTypography.labelSmall),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.of(context).textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyRow(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.of(context).gold.withValues(alpha: 0.15),
              borderRadius: AppRadius.sm_,
            ),
            child: Icon(icon, color: AppColors.of(context).gold, size: 20),
          ),
          title: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          trailing: Text(value, style: AppTypography.headlineSmall),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 64,
            color: AppColors.of(context).surfaceBorder,
          ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Registra al menos 2 entrenamientos para ver la gráfica',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
      );
    }

    final ordered = [...data]..sort((a, b) => a.date.compareTo(b.date));
    final first = ordered.first.date;
    final last = ordered.last.date;

    // Convert BEFORE calculating bounds. Otherwise lb data can fall outside
    // a chart whose vertical scale was constructed from kg.
    final spots = [
      for (final point in ordered)
        FlSpot(
          ProgressChartStyle.elapsedDays(point.date, first),
          WeightConverter.displayWeight(point.value, weightUnit),
        ),
    ];
    final bounds = ProgressChartStyle.bounds(spots.map((point) => point.y));
    final maxX = spots.last.x;
    final xPadding = math.max(0.65, maxX * 0.045);

    return Semantics(
      label: 'Evolución del 1RM estimado: '
          '${ProgressChartStyle.detailedDate(first)} a '
          '${ProgressChartStyle.detailedDate(last)}',
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) =>
                          ProgressChartStyle.tooltipBackground(context),
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final selected = ordered[spot.spotIndex];
                        return LineTooltipItem(
                          '${ProgressChartStyle.detailedDate(selected.date)}\n'
                          '${ProgressChartStyle.measurement(spot.y, weightUnit)}',
                          ProgressChartStyle.tooltipText(context),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: ProgressChartStyle.gridColor(context),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: -xPadding,
                  maxX: maxX + xPadding,
                  minY: bounds.minY,
                  maxY: bounds.maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: AppColors.of(context).primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.of(context).surfaceHigh,
                              strokeWidth: 2,
                              strokeColor: AppColors.of(context).primary,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.of(context)
                            .primary.withValues(alpha: 0.14),
                        cutOffY: bounds.minY,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ProgressChartStyle.date(first),
                      style: ProgressChartStyle.axisText(context)),
                  Text(ProgressChartStyle.date(last),
                      style: ProgressChartStyle.axisText(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
