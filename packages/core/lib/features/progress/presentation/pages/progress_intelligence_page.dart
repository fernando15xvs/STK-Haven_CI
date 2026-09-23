import 'dart:math' as math;

import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/unilateral_progress_summary.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProgressPeriod {
  days30('30 días', 30),
  days90('90 días', 90),
  all('Todo', null);

  const ProgressPeriod(this.label, this.days);
  final String label;
  final int? days;
}

class ProgressIntelligencePage extends ConsumerStatefulWidget {
  const ProgressIntelligencePage({super.key});

  @override
  ConsumerState<ProgressIntelligencePage> createState() =>
      _ProgressIntelligencePageState();
}

class _ProgressIntelligencePageState
    extends ConsumerState<ProgressIntelligencePage> {
  ProgressPeriod _period = ProgressPeriod.days90;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);
    final exercises = ref.watch(exerciseListProvider);
    final settings = ref.watch(settingsProvider);
    final from = _period.days == null
        ? null
        : DateTime.now().subtract(Duration(days: _period.days!));

    final entries = <_ProgressEntry>[];
    final groupVolume = <String, double>{};
    for (final exercise in exercises) {
      final trend = ExerciseProgressCalculator.calculateTrend(
        history,
        exercise.id,
        from: from,
        maxChartPoints: settings.performanceMode == PerformanceMode.savings
            ? 48
            : 120,
      );
      if (!trend.hasRecordedWork) continue;
      entries.add(_ProgressEntry(exercise: exercise, trend: trend));
      final group = exercise.muscleGroup.trim().isEmpty
          ? 'Sin grupo'
          : exercise.muscleGroup.trim();
      groupVolume.update(
        group,
        (value) => value + trend.totalVolume,
        ifAbsent: () => trend.totalVolume,
      );
    }
    entries.sort(
      (a, b) => (b.trend.lastPerformedAt ?? DateTime(1970))
          .compareTo(a.trend.lastPerformedAt ?? DateTime(1970)),
    );
    final groups = groupVolume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteligencia de progreso'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ProgressPeriod>(
                value: _period,
                items: ProgressPeriod.values
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(period.label),
                      ),
                    )
                    .toList(),
                onChanged: (period) {
                  if (period != null) setState(() => _period = period);
                },
              ),
            ),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Todavía no hay suficientes series de trabajo completadas en este período.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                Text(
                  'VOLUMEN POR GRUPO · ${_period.label.toUpperCase()}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Container(
                        width: 145,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const Spacer(),
                            Text(
                              FitnessFormatter.formatVolume(
                                group.value,
                                settings.weightUnit,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${entries.length} ejercicios con historial',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExerciseInsightCard(
                      entry: entry,
                      unit: settings.weightUnit,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProgressEntry {
  const _ProgressEntry({required this.exercise, required this.trend});
  final Exercise exercise;
  final ExerciseProgressTrend trend;
}

class _ExerciseInsightCard extends StatelessWidget {
  const _ExerciseInsightCard({required this.entry, required this.unit});

  final _ProgressEntry entry;
  final WeightUnit unit;

  int get _maxReps {
    var best = 0;
    for (final session in entry.trend.sessions) {
      if (session.bestReps > best) best = session.bestReps;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final trend = entry.trend;
    final latest = trend.latestSession!;
    final comparison = trend.latestComparison;
    final unilateral = UnilateralProgressCalculator.fromTrend(trend);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const Icon(Icons.insights_rounded),
        title: Text(
          entry.exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${latest.routineName.isEmpty ? 'Entrenamiento libre' : latest.routineName} · ${_date(latest.date)}',
        ),
        trailing: trend.hasPlateauSignal
            ? const Tooltip(
                message: 'Tres observaciones recientes dentro de un rango estrecho',
                child: Icon(Icons.horizontal_rule_rounded),
              )
            : null,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(
                label: 'e1RM',
                value: FitnessFormatter.formatWeight(trend.current1RM, unit),
              ),
              _Metric(
                label: 'PR carga',
                value: FitnessFormatter.formatWeight(trend.maxWeight, unit),
              ),
              _Metric(label: 'PR reps', value: '$_maxReps reps'),
              _Metric(
                label: 'PR volumen',
                value: FitnessFormatter.formatVolume(trend.bestSetVolume, unit),
              ),
              _Metric(label: 'Sesiones', value: '${trend.sessionCount}'),
            ],
          ),
          if (comparison != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ÚLTIMA VS ANTERIOR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Delta(
                  label: 'Peso',
                  value: _weightDelta(comparison.weightDelta, unit),
                ),
                _Delta(
                  label: 'Reps',
                  value: _signed(comparison.repsDelta.toDouble(), 0),
                ),
                if (comparison.rirDelta != null)
                  _Delta(
                    label: 'RIR',
                    value: _signed(comparison.rirDelta!, 1),
                  ),
                _Delta(
                  label: 'e1RM',
                  value: _weightDelta(comparison.estimated1RmDelta, unit),
                ),
                _Delta(
                  label: 'Volumen',
                  value: _weightDelta(comparison.volumeDelta, unit),
                ),
              ],
            ),
          ],
          if (unilateral.hasComparison) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'UNILATERAL POR LADO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Valores registrados por lado. Se presentan como contexto descriptivo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (unilateral.leftEstimated1RM != null)
                  _Metric(
                    label: 'I · e1RM actual',
                    value: FitnessFormatter.formatWeight(
                      unilateral.leftEstimated1RM!,
                      unit,
                    ),
                  ),
                if (unilateral.rightEstimated1RM != null)
                  _Metric(
                    label: 'D · e1RM actual',
                    value: FitnessFormatter.formatWeight(
                      unilateral.rightEstimated1RM!,
                      unit,
                    ),
                  ),
                if (unilateral.leftVolume != null)
                  _Metric(
                    label: 'I · volumen',
                    value: FitnessFormatter.formatVolume(
                      unilateral.leftVolume!,
                      unit,
                    ),
                  ),
                if (unilateral.rightVolume != null)
                  _Metric(
                    label: 'D · volumen',
                    value: FitnessFormatter.formatVolume(
                      unilateral.rightVolume!,
                      unit,
                    ),
                  ),
                if (unilateral.bestLeftEstimated1RM != null)
                  _Metric(
                    label: 'I · PR e1RM',
                    value: FitnessFormatter.formatWeight(
                      unilateral.bestLeftEstimated1RM!,
                      unit,
                    ),
                  ),
                if (unilateral.bestRightEstimated1RM != null)
                  _Metric(
                    label: 'D · PR e1RM',
                    value: FitnessFormatter.formatWeight(
                      unilateral.bestRightEstimated1RM!,
                      unit,
                    ),
                  ),
                if (unilateral.bestLeftVolume != null)
                  _Metric(
                    label: 'I · máx. volumen',
                    value: FitnessFormatter.formatVolume(
                      unilateral.bestLeftVolume!,
                      unit,
                    ),
                  ),
                if (unilateral.bestRightVolume != null)
                  _Metric(
                    label: 'D · máx. volumen',
                    value: FitnessFormatter.formatVolume(
                      unilateral.bestRightVolume!,
                      unit,
                    ),
                  ),
              ],
            ),
            if (unilateral.estimated1RmDifferencePercent != null) ...[
              const SizedBox(height: 8),
              _InfoMessage(
                icon: Icons.compare_arrows_rounded,
                text:
                    'Última ejecución: diferencia de e1RM entre lados ${unilateral.estimated1RmDifferencePercent!.toStringAsFixed(1)}%. No clasifica un lado como mejor o peor.',
              ),
            ],
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TENDENCIAS',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          _TrendLine(
            label: 'Peso',
            points: trend.historyWeight,
            formatter: (value) => FitnessFormatter.formatWeight(value, unit),
          ),
          _TrendLine(
            label: 'Reps',
            points: trend.historyReps,
            formatter: (value) => '${value.round()} reps',
          ),
          _TrendLine(
            label: 'RIR',
            points: trend.historyRir,
            formatter: (value) => value.toStringAsFixed(1),
          ),
          _TrendLine(
            label: 'e1RM',
            points: trend.history1RM,
            formatter: (value) => FitnessFormatter.formatWeight(value, unit),
          ),
          if (trend.hasPlateauSignal) ...[
            const SizedBox(height: 10),
            const _InfoMessage(
              icon: Icons.info_outline_rounded,
              text:
                  'Señal informativa: las últimas tres estimaciones de 1RM están dentro de un rango aproximado del 2%. Observa técnica, recuperación y contexto antes de cambiar el plan.',
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SESIONES RECIENTES',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ...trend.sessions.reversed.take(5).map(
                (session) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    session.routineName.isEmpty
                        ? 'Entrenamiento libre'
                        : session.routineName,
                  ),
                  subtitle: Text(
                    '${_date(session.date)} · ${FitnessFormatter.formatWeight(session.bestWeight, unit)} × ${session.bestReps}${session.averageRir == null ? '' : ' · RIR ${session.averageRir!.toStringAsFixed(1)}'}',
                  ),
                  trailing: Text(
                    FitnessFormatter.formatWeight(session.estimated1RM, unit),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _signed(double value, int decimals) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}';
  }

  static String _weightDelta(double kg, WeightUnit unit) {
    final converted = WeightConverter.displayWeight(kg.abs(), unit);
    final sign = kg > 0 ? '+' : kg < 0 ? '-' : '';
    return '$sign${converted.toStringAsFixed(1)} ${unit.label}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label $value', style: Theme.of(context).textTheme.bodySmall);
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({
    required this.label,
    required this.points,
    required this.formatter,
  });
  final String label;
  final List<ExerciseProgressPoint> points;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final first = points.first.value;
    final latest = points.last.value;
    final low = points.map((item) => item.value).reduce(math.min);
    final high = points.map((item) => item.value).reduce(math.max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(label)),
          Expanded(
            child: Text(
              '${formatter(first)} → ${formatter(latest)} · rango ${formatter(low)}–${formatter(high)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
