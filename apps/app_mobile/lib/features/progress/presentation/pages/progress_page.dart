import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/widgets/recent_workout_details.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/muscle_heatmap_grid.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/calendar_heatmap_card.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:gym_tracker/core/theme/components/metric_tile.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Progreso', style: AppTypography.displaySmall),
          centerTitle: false,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.of(context).primary,
            unselectedLabelColor: AppColors.of(context).textSecondary,
            labelStyle: AppTypography.labelLarge,
            unselectedLabelStyle: AppTypography.labelLarge,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: AppColors.of(context).primary,
                width: 3,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Ejercicios'),
              Tab(text: 'Músculos'),
              Tab(text: 'Medidas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _SummaryTab(),
            ProgressExercisesPanel(
              onOpenExercise: (exercise) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: exercise)),
              ),
            ),
            const MuscleHeatmapGrid(),
            const BodyMeasurementPage(),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(progressMetricsProvider);
    final filter = ref.watch(timeFilterProvider);
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.of(context).surfaceHigh,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.of(context).surfaceBorder),
          ),
          padding: const EdgeInsets.all(4),
          child: SegmentedButton<TimeFilter>(
            segments: const [
              ButtonSegment(value: TimeFilter.week, label: Text('7D')),
              ButtonSegment(value: TimeFilter.month, label: Text('1M')),
              ButtonSegment(value: TimeFilter.threeMonths, label: Text('3M')),
              ButtonSegment(value: TimeFilter.year, label: Text('1A')),
            ],
            selected: {filter},
            onSelectionChanged: (Set<TimeFilter> newSelection) {
              ref
                  .read(timeFilterProvider.notifier)
                  .setFilter(newSelection.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.of(context).primary.withValues(alpha: 0.15);
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.of(context).primary;
                }
                return AppColors.of(context).textSecondary;
              }),
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: AppRadius.md_),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'VOLUMEN TOTAL',
          style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              NumberFormat.decimalPattern().format(
                WeightConverter.displayWeight(
                  metrics.totalVolume,
                  settings.weightUnit,
                ).toInt(),
              ),
              style: AppTypography.displayMedium.copyWith(letterSpacing: -1),
            ),
            const SizedBox(width: 6),
            Text(
              settings.weightUnit.label.toUpperCase(),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const Spacer(),
            if (metrics.volumePercentChange != null)
              _TrendBadge(value: metrics.volumePercentChange!),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.of(context).surfaceBorder),
            boxShadow: AppElevation.soft(context),
          ),
          child: VolumeChart(
            data: metrics.volumeChartData,
            weightUnit: settings.weightUnit,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _ConsistencyCard(metrics: metrics, filter: filter),
        const SizedBox(height: AppSpacing.xxl),
        CalendarHeatmapCard(
          snapshot: metrics.calendarHeatmap,
          periodLabel: filter.label,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'ESTE PERIODO (${filter.label.toUpperCase()})',
          style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Entrenamientos',
                value: '${metrics.workoutCount}',
                icon: Icon(
                  Icons.fitness_center,
                  size: 16,
                  color: AppColors.of(context).primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                label: 'Series',
                value: '${metrics.totalSets}',
                icon: const Icon(
                  Icons.layers,
                  size: 16,
                  color: Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Tiempo',
                value: _formatDuration(metrics.totalDurationSeconds),
                icon: const Icon(
                  Icons.timer,
                  size: 16,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                label: 'Récords',
                value: '${metrics.prCount} PRs',
                icon: Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: AppColors.of(context).gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'ENTRENAMIENTOS RECIENTES',
          style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: AppSpacing.md),
        if (history.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No hay entrenamientos recientes',
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: AppRadius.lg_,
              border: Border.all(color: AppColors.of(context).surfaceBorder),
              boxShadow: AppElevation.soft(context),
            ),
            child: Column(
              children: history.take(6).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final session = entry.value;
                final isLast = idx == (history.take(6).length - 1);
                return Column(
                  children: [
                    ListTile(
                      onTap: () => RecentWorkoutDetails.show(
                        context,
                        session,
                        settings.weightUnit,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).primaryFaded,
                          borderRadius: AppRadius.sm_,
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          color: AppColors.of(context).primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        session.routineNameSnapshot.isEmpty
                            ? 'Entrenamiento libre'
                            : session.routineNameSnapshot,
                        style: AppTypography.headlineSmall,
                      ),
                      subtitle: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          'es',
                        ).format(session.startedAt),
                        style: AppTypography.bodySmall,
                      ),
                      trailing: Text(
                        '${session.durationSeconds ~/ 60} min',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.of(context).textSecondary,
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 64, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _ConsistencyCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final TimeFilter filter;

  const _ConsistencyCard({required this.metrics, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.of(context).surfaceBorder),
        boxShadow: AppElevation.soft(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.of(context).primaryFaded,
                  borderRadius: AppRadius.sm_,
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.of(context).primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONSISTENCIA',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).primary,
                      ),
                    ),
                    Text(
                      'Ritmo de entrenamiento · ${filter.label}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (metrics.workoutFrequencyPercentChange != null)
                _TrendBadge(value: metrics.workoutFrequencyPercentChange!),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _InsightMetric(
                  label: 'DÍAS ACTIVOS',
                  value: '${metrics.activeDays}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _InsightMetric(
                  label: 'ENTRENOS / SEM',
                  value: metrics.workoutsPerWeek.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _InsightMetric(
                  label: 'DURACIÓN MEDIA',
                  value: '${metrics.averageSessionMinutes.round()}m',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InsightMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceHigh,
        borderRadius: AppRadius.sm_,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.headlineMedium),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double value;

  const _TrendBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive
        ? AppColors.of(context).success
        : AppColors.of(context).error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.sm_,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

