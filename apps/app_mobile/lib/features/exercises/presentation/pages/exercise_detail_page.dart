import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_demonstration_card.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_history_page.dart';
import 'package:gym_tracker/features/progress/presentation/pages/focused_exercise_progress_page.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:fl_chart/fl_chart.dart';
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

          // Personal metrics live in Progreso, and the full read-only
          // session record lives in its own history route. Do not duplicate
          // PRs, charts or five-session previews in the technical ficha.
          Text(
            'MIS REGISTROS',
            style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceHigh,
              borderRadius: AppRadius.lg_,
              border: Border.all(
                color: AppColors.of(context).surfaceBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('exercise_open_progress'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FocusedExerciseProgressPage(exercise: exercise),
                    ),
                  ),
                  leading: Icon(
                    Icons.insights_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'Ver mi rendimiento',
                    style: AppTypography.headlineSmall,
                  ),
                  subtitle: Text(
                    'Tendencias y récords de este ejercicio',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppColors.of(context).surfaceBorder,
                ),
                ListTile(
                  key: const ValueKey('exercise_open_history'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExerciseHistoryPage(exercise: exercise),
                    ),
                  ),
                  leading: Icon(
                    Icons.history_outlined,
                    color: AppColors.of(context).primary,
                  ),
                  title: Text(
                    'Ver historial completo',
                    style: AppTypography.headlineSmall,
                  ),
                  subtitle: Text(
                    'Todas tus sesiones y series registradas',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
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

}

class ExerciseOneRmChart extends StatelessWidget {
  final List<ExerciseProgressPoint> data;
  final WeightUnit weightUnit;

  const ExerciseOneRmChart({required this.data, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    // Multiple sessions on the same day must not create overlapping points.
    // The latest observation of each local day is the honest daily trend;
    // all underlying sessions remain intact in the exercise history.
    final sorted = data.where((p) => p.value.isFinite && p.value >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final latestByDay = <DateTime, ExerciseProgressPoint>{};
    for (final point in sorted) {
      latestByDay[DateTime(point.date.year, point.date.month, point.date.day)] =
          point;
    }
    final ordered = latestByDay.values.toList(growable: false);
    if (ordered.length < 2) {
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
    final peakSpot = spots.reduce((a, b) => a.y >= b.y ? a : b);
    final peakDate = ordered[spots.indexOf(peakSpot)].date;

    return Semantics(
      label: 'Evolución del 1RM estimado: '
          '${ProgressChartStyle.detailedDate(first)} a '
          '${ProgressChartStyle.detailedDate(last)}. '
          'Última estimación: ${ProgressChartStyle.measurement(spots.last.y, weightUnit)}. '
          'Máximo mostrado: ${ProgressChartStyle.measurement(peakSpot.y, weightUnit)} '
          'el ${ProgressChartStyle.detailedDate(peakDate)}.',
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
                      maxContentWidth: ProgressChartStyle.tooltipMaxContentWidth,
                      tooltipPadding: ProgressChartStyle.tooltipPadding,
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
