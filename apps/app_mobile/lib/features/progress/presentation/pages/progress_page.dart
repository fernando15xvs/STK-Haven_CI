import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/progress/application/progress_insight_calculator.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_insights_panel.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/muscle_heatmap_grid.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/calendar_heatmap_card.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:gym_tracker/features/progress/presentation/pages/focused_exercise_progress_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_history_page.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_volume_headline.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_consistency_metrics.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_shared_period_selector.dart';
import 'package:gym_tracker/features/progress/presentation/pages/body_measurement_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key, this.summaryAnchorKey});

  /// A descendant anchor lets Home open Resumen on the retained tab without
  /// recreating Progreso or resetting its shared period/filter state.
  final Key? summaryAnchorKey;

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
        // A single period control serves Resumen, Ejercicios and Músculos.
        // Medidas keeps its separate, measurement-specific date range.
        body: Builder(
          key: summaryAnchorKey,
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabs,
              builder: (context, _) => Column(
                children: [
                  // Keep TabBarView at the same child position when the
                  // Medidas tab hides the cross-tab selector. Otherwise
                  // Flutter may recreate its state during tab animations.
                  tabs.index == 3
                      ? const SizedBox.shrink()
                      : const ProgressSharedPeriodSelector(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        const ProgressSummaryTab(),
                        ProgressExercisesPanel(
                          useSharedPeriod: true,
                          onOpenPerformance: (exercise) =>
                              Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  FocusedExerciseProgressPage(exercise: exercise),
                            ),
                          ),
                          onOpenExercise: (exercise) =>
                              Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ExerciseDetailPage(exercise: exercise),
                            ),
                          ),
                          onOpenHistory: (exercise) =>
                              Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ExerciseHistoryPage(exercise: exercise),
                            ),
                          ),
                        ),
                        const MuscleHeatmapGrid(),
                        const BodyMeasurementPage(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Resumen is a focused overview; full workout details remain in Historial.
class ProgressSummaryTab extends ConsumerWidget {
  const ProgressSummaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(progressMetricsProvider);
    final filter = ref.watch(timeFilterProvider);
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);
    final exercises = ref.watch(exerciseListProvider);
    final now = DateTime.now();
    final insights = ProgressInsightCalculator.calculate(
      history: history,
      exercises: exercises,
      from: filter.startDateAt(now),
      now: now,
      periodKey: filter.label,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          'VOLUMEN TOTAL',
          style: AppTypography.labelMedium.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        ProgressVolumeHeadline(
          volumeKg: metrics.totalVolume,
          weightUnit: settings.weightUnit,
          trailing: metrics.volumePercentChange == null
              ? null
              : _TrendBadge(value: metrics.volumePercentChange!),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            'TENDENCIA DE VOLUMEN · ${filter.label}',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
            period: filter,
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
        ProgressInsightsPanel(insights: insights),
        const SizedBox(height: 80),
      ],
    );
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
          ProgressConsistencyMetrics(
            workoutsPerWeek: metrics.workoutsPerWeek,
            averageSessionMinutes: metrics.averageSessionMinutes,
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
    final palette = AppColors.of(context);
    final positive = value >= 0;
    final statusColor = positive ? palette.success : palette.error;
    // Numbers use a Spanish decimal separator and don't rely on the tint
    // alone: semantic label and high-contrast primary text describe the trend.
    final formatted = '${value > 0 ? '+' : ''}${value.toStringAsFixed(1).replaceAll('.', ',')}%';
    return Semantics(
      label: '${positive ? 'Tendencia positiva' : 'Tendencia negativa'}: $formatted',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: AppRadius.sm_,
          border: Border.all(color: palette.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive ? Icons.trending_up : Icons.trending_down,
              color: statusColor,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              formatted,
              key: const ValueKey('progress_trend_percent'),
              style: AppTypography.labelMedium.copyWith(
                color: palette.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

