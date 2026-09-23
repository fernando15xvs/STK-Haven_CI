import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/muscle_heatmap_grid.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/calendar_heatmap_card.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
import 'package:core/domain/models/settings_state.dart';
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
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTypography.labelLarge,
            unselectedLabelStyle: AppTypography.labelLarge,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.primary, width: 3),
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
        body: const TabBarView(
          children: [
            _SummaryTab(),
            _ExercisesTab(),
            MuscleHeatmapGrid(),
            BodyMeasurementPage(),
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
            color: AppColors.surfaceHigh,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.surfaceBorder),
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
              ref.read(timeFilterProvider.notifier).setFilter(newSelection.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary.withValues(alpha: 0.15);
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return AppColors.textSecondary;
              }),
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: AppRadius.md_),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('VOLUMEN TOTAL', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              NumberFormat.decimalPattern().format(
                WeightConverter.displayWeight(metrics.totalVolume, settings.weightUnit).toInt(),
              ),
              style: AppTypography.displayMedium.copyWith(letterSpacing: -1),
            ),
            const SizedBox(width: 6),
            Text(
              settings.weightUnit.label.toUpperCase(),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
            color: AppColors.surface,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: AppElevation.soft,
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
                icon: const Icon(Icons.fitness_center, size: 16, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                label: 'Series',
                value: '${metrics.totalSets}',
                icon: const Icon(Icons.layers, size: 16, color: Colors.purpleAccent),
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
                icon: const Icon(Icons.timer, size: 16, color: Colors.orangeAccent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                label: 'Récords',
                value: '${metrics.prCount} PRs',
                icon: const Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('ENTRENAMIENTOS RECIENTES', style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: AppSpacing.md),
        if (history.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No hay entrenamientos recientes', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lg_,
              border: Border.all(color: AppColors.surfaceBorder),
              boxShadow: AppElevation.soft,
            ),
            child: Column(
              children: history.take(3).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final session = entry.value;
                final isLast = idx == (history.take(3).length - 1);
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primaryFaded, borderRadius: AppRadius.sm_),
                        child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        session.routineNameSnapshot.isEmpty ? 'Entrenamiento libre' : session.routineNameSnapshot,
                        style: AppTypography.headlineSmall,
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy', 'es').format(session.startedAt),
                        style: AppTypography.bodySmall,
                      ),
                      trailing: Text(
                        '${session.durationSeconds ~/ 60} min',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 64, endIndent: 16),
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
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primaryFaded, borderRadius: AppRadius.sm_),
                child: const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONSISTENCIA', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                    Text('Ritmo de entrenamiento · ${filter.label}', style: AppTypography.bodySmall),
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
              Expanded(child: _InsightMetric(label: 'DÍAS ACTIVOS', value: '${metrics.activeDays}')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _InsightMetric(label: 'ENTRENOS / SEM', value: metrics.workoutsPerWeek.toStringAsFixed(1))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _InsightMetric(label: 'DURACIÓN MEDIA', value: '${metrics.averageSessionMinutes.round()}m')),
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
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.sm_),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.headlineMedium),
          const SizedBox(height: 3),
          Text(label, style: AppTypography.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final color = positive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.sm_,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(positive ? Icons.trending_up : Icons.trending_down, color: color, size: 14),
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

class _ExercisesTab extends ConsumerWidget {
  const _ExercisesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exerciseListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);

    final dashboards = exercises
        .map(
          (exercise) => MapEntry(
            exercise,
            ExerciseProgressCalculator.calculateTrend(history, exercise.id),
          ),
        )
        .where((entry) => entry.value.hasRecordedWork)
        .toList()
      ..sort((a, b) {
        final aDate = a.value.lastPerformedAt;
        final bDate = b.value.lastPerformedAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    if (dashboards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text(
                'Aún no hay progreso por ejercicio',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Completa series de trabajo para construir tu dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        96,
      ),
      itemCount: dashboards.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DASHBOARD POR EJERCICIO',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Solo cuenta series de trabajo completadas; calentamiento y aproximación no alteran estas métricas.',
                style: AppTypography.bodySmall.copyWith(height: 1.35),
              ),
            ],
          );
        }

        final entry = dashboards[index - 1];
        final exercise = entry.key;
        final dashboard = entry.value;
        final lastDate = dashboard.lastPerformedAt == null
            ? 'Sin fecha'
            : DateFormat('dd MMM yyyy', 'es').format(dashboard.lastPerformedAt!);
        final e1RM = dashboard.current1RM <= 0
            ? '—'
            : FitnessFormatter.formatWeight(
                dashboard.current1RM,
                settings.weightUnit,
              );
        final maxWeight = dashboard.maxWeight <= 0
            ? '—'
            : FitnessFormatter.formatWeight(
                dashboard.maxWeight,
                settings.weightUnit,
              );
        final volume = FitnessFormatter.formatWeight(
          dashboard.totalVolume,
          settings.weightUnit,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.lg_,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExerciseDetailPage(exercise: exercise),
                ),
              );
            },
            child: Ink(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg_,
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: AppElevation.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFaded,
                          borderRadius: AppRadius.sm_,
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: AppTypography.headlineMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${exercise.muscleGroup} · Última: $lastDate',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (dashboard.percentChange30Days != null)
                        _TrendBadge(value: dashboard.percentChange30Days!)
                      else
                        Text(
                          'Sin base 30D',
                          style: AppTypography.labelSmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseMetric(
                          label: 'e1RM ACTUAL',
                          value: e1RM,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ExerciseMetric(
                          label: 'CARGA MÁX.',
                          value: maxWeight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseMetric(
                          label: 'SESIONES',
                          value: '${dashboard.sessionCount}',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ExerciseMetric(
                          label: 'SERIES TRABAJO',
                          value: '${dashboard.completedWorkSets}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: AppRadius.sm_,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stacked_line_chart,
                          color: AppColors.primary,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Volumen acumulado',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                        Text(volume, style: AppTypography.labelLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dashboard.history1RM.length < 2
                              ? 'La tendencia e1RM aparecerá con más sesiones.'
                              : '${dashboard.history1RM.length} puntos de e1RM registrados',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ExerciseMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.sm_,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
