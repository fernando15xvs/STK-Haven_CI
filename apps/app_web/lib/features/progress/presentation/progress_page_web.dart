import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/calendar_heatmap_panel_web.dart';

class ProgressPageWeb extends StatelessWidget {
  const ProgressPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Text('Progreso', style: AppTypography.displaySmall),
                  ),
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Resumen'),
                      Tab(text: 'Ejercicios'),
                      Tab(text: 'Músculos'),
                      Tab(text: 'Medidas'),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _SummaryTabWeb(),
                        _ExerciseProgressTabWeb(),
                        _MuscleProgressTabWeb(),
                        _MeasurementsTabWeb(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTabWeb extends ConsumerWidget {
  const _SummaryTabWeb();

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(progressMetricsProvider);
    final filter = ref.watch(timeFilterProvider);
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);
    final displayedVolume = WeightConverter.displayWeight(
      metrics.totalVolume,
      settings.weightUnit,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<TimeFilter>(
            segments: const [
              ButtonSegment(value: TimeFilter.week, label: Text('7D')),
              ButtonSegment(value: TimeFilter.month, label: Text('1M')),
              ButtonSegment(value: TimeFilter.threeMonths, label: Text('3M')),
              ButtonSegment(value: TimeFilter.year, label: Text('1A')),
            ],
            selected: {filter},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                ref.read(timeFilterProvider.notifier).setFilter(value.first),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 820
                ? 4
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
            final cards = [
              _MetricCard(
                title: 'Volumen',
                value:
                    '${displayedVolume.toStringAsFixed(0)} ${settings.weightUnit.label}',
                icon: Icons.monitor_weight_outlined,
              ),
              _MetricCard(
                title: 'Entrenamientos',
                value: '${metrics.workoutCount}',
                icon: Icons.fitness_center,
              ),
              _MetricCard(
                title: 'Series',
                value: '${metrics.totalSets}',
                icon: Icons.layers_outlined,
              ),
              _MetricCard(
                title: 'Tiempo',
                value: _duration(metrics.totalDurationSeconds),
                icon: Icons.timer_outlined,
              ),
            ];
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.4 : 2.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cards,
            );
          },
        ),
        const SizedBox(height: 18),
        _ConsistencyPanel(metrics: metrics, filter: filter),
        const SizedBox(height: 18),
        CalendarHeatmapPanelWeb(
          snapshot: metrics.calendarHeatmap,
          periodLabel: filter.label,
        ),
        const SizedBox(height: 18),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Volumen por día',
                      style: AppTypography.headlineLarge,
                    ),
                  ),
                  if (metrics.volumePercentChange != null)
                    _TrendBadge(value: metrics.volumePercentChange!),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 220,
                child: metrics.volumeChartData.isEmpty
                    ? Center(
                        child: Text(
                          'Aún no hay datos en este periodo.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: _VolumePainter(
                          data: metrics.volumeChartData
                              .map(
                                (point) => WeightConverter.displayWeight(
                                  point.volume,
                                  settings.weightUnit,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Entrenamientos recientes', style: AppTypography.headlineLarge),
        const SizedBox(height: 10),
        if (history.isEmpty)
          _Panel(
            child: Text(
              'Aún no hay entrenamientos guardados.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          _Panel(
            child: Column(
              children: history.take(8).map((session) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    session.routineNameSnapshot.isEmpty
                        ? 'Entrenamiento libre'
                        : session.routineNameSnapshot,
                  ),
                  subtitle: Text(_date(session.startedAt)),
                  trailing: Text(
                    '${session.durationSeconds ~/ 60} min',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _ConsistencyPanel extends StatelessWidget {
  final DashboardMetrics metrics;
  final TimeFilter filter;

  const _ConsistencyPanel({required this.metrics, required this.filter});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaded,
                  borderRadius: AppRadius.md_,
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consistencia', style: AppTypography.headlineLarge),
                    Text(
                      'Ritmo de entrenamiento · ${filter.label}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (metrics.workoutFrequencyPercentChange != null)
                _TrendBadge(value: metrics.workoutFrequencyPercentChange!),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final cards = [
                _InsightMetric(
                  label: 'DÍAS ACTIVOS',
                  value: '${metrics.activeDays}',
                  icon: Icons.event_available_outlined,
                ),
                _InsightMetric(
                  label: 'ENTRENOS / SEM',
                  value: metrics.workoutsPerWeek.toStringAsFixed(1),
                  icon: Icons.repeat_rounded,
                ),
                _InsightMetric(
                  label: 'DURACIÓN MEDIA',
                  value: '${metrics.averageSessionMinutes.round()} min',
                  icon: Icons.schedule,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 8),
                    cards[1],
                    const SizedBox(height: 8),
                    cards[2],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InsightMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTypography.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    final color = positive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

class _ExerciseProgressTabWeb extends ConsumerWidget {
  const _ExerciseProgressTabWeb();

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exerciseListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);

    final dashboards = exercises
        .map(
          (exercise) => (
            exercise: exercise,
            trend: ExerciseProgressCalculator.calculateTrend(
              history,
              exercise.id,
            ),
          ),
        )
        .where((entry) => entry.trend.hasRecordedWork)
        .toList()
      ..sort((a, b) {
        final aDate = a.trend.lastPerformedAt;
        final bDate = b.trend.lastPerformedAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    if (dashboards.isEmpty) {
      return const _CenteredEmpty(
        icon: Icons.query_stats,
        title: 'Aún no hay progreso por ejercicio',
        message:
            'Completa series de trabajo para construir métricas por ejercicio.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        final aspectRatio = columns == 1
            ? 2.25
            : columns == 2
                ? 1.08
                : 0.92;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: dashboards.length,
          itemBuilder: (context, index) {
            final entry = dashboards[index];
            final dashboard = entry.trend;
            final current1RM = WeightConverter.displayWeight(
              dashboard.current1RM,
              settings.weightUnit,
            );
            final maxWeight = WeightConverter.displayWeight(
              dashboard.maxWeight,
              settings.weightUnit,
            );
            final totalVolume = WeightConverter.displayWeight(
              dashboard.totalVolume,
              settings.weightUnit,
            );
            final lastSessionVolume = WeightConverter.displayWeight(
              dashboard.lastSessionVolume,
              settings.weightUnit,
            );
            final chartData = dashboard.history1RM
                .map(
                  (point) => WeightConverter.displayWeight(
                    point.value,
                    settings.weightUnit,
                  ),
                )
                .toList(growable: false);

            return _Panel(
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
                          borderRadius: AppRadius.md_,
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.exercise.name,
                              style: AppTypography.headlineSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.exercise.muscleGroup,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
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
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseMetricWeb(
                          label: 'e1RM ACTUAL',
                          value: dashboard.current1RM <= 0
                              ? '—'
                              : '${current1RM.toStringAsFixed(1)} ${settings.weightUnit.label}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ExerciseMetricWeb(
                          label: 'CARGA MÁX.',
                          value: dashboard.maxWeight <= 0
                              ? '—'
                              : '${maxWeight.toStringAsFixed(1)} ${settings.weightUnit.label}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseMetricWeb(
                          label: 'SESIONES',
                          value: '${dashboard.sessionCount}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ExerciseMetricWeb(
                          label: 'SERIES TRABAJO',
                          value: '${dashboard.completedWorkSets}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Volumen acumulado',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${totalVolume.toStringAsFixed(0)} ${settings.weightUnit.label}',
                        style: AppTypography.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dashboard.lastPerformedAt == null
                              ? 'Sin sesión reciente'
                              : 'Última ${_date(dashboard.lastPerformedAt!)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${lastSessionVolume.toStringAsFixed(0)} ${settings.weightUnit.label} vol.',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (chartData.length >= 2) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tendencia e1RM',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: CustomPaint(
                        painter: _VolumePainter(data: chartData),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const SizedBox(height: 6),
                  Text(
                    'Solo series de trabajo completadas; preparación e incompletas quedan fuera.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ExerciseMetricWeb extends StatelessWidget {
  final String label;
  final String value;

  const _ExerciseMetricWeb({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.md_,
        border: Border.all(color: AppColors.border),
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
          const SizedBox(height: 2),
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

class _MuscleProgressTabWeb extends ConsumerWidget {
  const _MuscleProgressTabWeb();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    final settings = ref.watch(settingsProvider);
    final map = <String, ({int sets, double volume})>{};

    for (final session in history) {
      for (final exercise in session.exercises) {
        final name = exercise.muscleGroupSnapshot.trim().isEmpty
            ? 'Sin grupo'
            : exercise.muscleGroupSnapshot.trim();
        var sets = 0;
        var volume = 0.0;
        for (final set in exercise.sets) {
          if (!set.completed || set.warmup) continue;
          sets++;
          volume += set.performedVolume;
        }
        final previous = map[name] ?? (sets: 0, volume: 0.0);
        map[name] = (
          sets: previous.sets + sets,
          volume: previous.volume + volume,
        );
      }
    }

    final entries = map.entries.toList()
      ..sort((a, b) => b.value.sets.compareTo(a.value.sets));
    if (entries.isEmpty) {
      return const _CenteredEmpty(
        icon: Icons.accessibility_new,
        title: 'Aún no hay trabajo muscular registrado',
        message:
            'Aquí verás qué grupos musculares has entrenado y cuánto volumen acumulas.',
      );
    }

    final maxSets = math.max(1, entries.first.value.sets);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final volume = WeightConverter.displayWeight(
          entry.value.volume,
          settings.weightUnit,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: AppTypography.headlineSmall,
                      ),
                    ),
                    Text(
                      '${entry.value.sets} series',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: entry.value.sets / maxSets,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 7),
                Text(
                  '${volume.toStringAsFixed(0)} ${settings.weightUnit.label} de volumen acumulado',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeasurementsTabWeb extends ConsumerWidget {
  const _MeasurementsTabWeb();

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(bodyMeasurementProvider);
    final settings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Medidas corporales',
                style: AppTypography.headlineLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: () =>
                  _showAddMeasurement(context, ref, settings.weightUnit),
              icon: const Icon(Icons.add),
              label: const Text('Registrar medida'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (measurements.isEmpty)
          const _CenteredEmpty(
            icon: Icons.straighten,
            title: 'No hay medidas registradas',
            message:
                'Registra peso y medidas corporales para seguir cambios fuera del gimnasio.',
          )
        else
          ...measurements.map((measurement) {
            final weight = measurement.weightKg == null
                ? null
                : WeightConverter.displayWeight(
                    measurement.weightKg!,
                    settings.weightUnit,
                  );
            final detail = <String>[
              if (weight != null)
                'Peso ${weight.toStringAsFixed(1)} ${settings.weightUnit.label}',
              if (measurement.bodyFatPercentage != null)
                'Grasa ${measurement.bodyFatPercentage!.toStringAsFixed(1)}%',
              if (measurement.chestCm != null)
                'Pecho ${measurement.chestCm!.toStringAsFixed(1)} cm',
              if (measurement.waistCm != null)
                'Cintura ${measurement.waistCm!.toStringAsFixed(1)} cm',
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.straighten, color: AppColors.primary),
                  title: Text(_date(measurement.date)),
                  subtitle: Text(
                    detail.isEmpty ? 'Registro corporal' : detail.join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar registro',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => ref
                        .read(bodyMeasurementProvider.notifier)
                        .deleteMeasurement(measurement.id),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showAddMeasurement(
    BuildContext context,
    WidgetRef ref,
    WeightUnit unit,
  ) async {
    final weight = TextEditingController();
    final fat = TextEditingController();
    final chest = TextEditingController();
    final waist = TextEditingController();
    final arm = TextEditingController();
    final leg = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar medidas'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MeasureField(
                  controller: weight,
                  label: 'Peso (${unit.label})',
                ),
                _MeasureField(
                  controller: fat,
                  label: 'Grasa corporal (%)',
                ),
                _MeasureField(controller: chest, label: 'Pecho (cm)'),
                _MeasureField(controller: waist, label: 'Cintura (cm)'),
                _MeasureField(controller: arm, label: 'Brazo (cm)'),
                _MeasureField(controller: leg, label: 'Pierna (cm)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      double? parse(TextEditingController controller) =>
          double.tryParse(controller.text.replaceAll(',', '.'));
      final displayedWeight = parse(weight);
      await ref.read(bodyMeasurementProvider.notifier).saveMeasurement(
            BodyMeasurement(
              id: 'measurement_${DateTime.now().microsecondsSinceEpoch}',
              date: DateTime.now(),
              weightKg: displayedWeight == null
                  ? null
                  : WeightConverter.toCanonicalKg(displayedWeight, unit),
              bodyFatPercentage: parse(fat),
              chestCm: parse(chest),
              waistCm: parse(waist),
              leftArmCm: parse(arm),
              rightArmCm: parse(arm),
              leftLegCm: parse(leg),
              rightLegCm: parse(leg),
            ),
          );
    }

    weight.dispose();
    fat.dispose();
    chest.dispose();
    waist.dispose();
    arm.dispose();
    leg.dispose();
  }
}

class _MeasureField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _MeasureField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.md_,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: child,
    );
  }
}

class _CenteredEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 58,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumePainter extends CustomPainter {
  final List<double> data;

  _VolumePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (data.isEmpty) return;

    final maxValue = math.max(1.0, data.reduce(math.max));
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? size.width / 2
          : size.width * i / (data.length - 1);
      final y = size.height - (data[i] / maxValue * (size.height - 12)) - 6;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    final lastX = data.length == 1 ? size.width / 2 : size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _VolumePainter oldDelegate) =>
      oldDelegate.data != data;
}
