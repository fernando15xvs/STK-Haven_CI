import 'dart:math' as math;

import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/exercise_progress_sort.dart';
import 'package:core/features/progress/application/progress_analytics_cache.dart' as analytics;
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/progress/application/unilateral_progress_summary.dart';
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

/// Compatibility route for existing links; the actual mobile entry is the
/// Progreso > Ejercicios tab, which uses the same shared panel.
class ProgressIntelligencePage extends StatelessWidget {
  const ProgressIntelligencePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progreso por ejercicio')),
    body: const ProgressExercisesPanel(),
  );
}

class ProgressExercisesPanel extends ConsumerStatefulWidget {
  const ProgressExercisesPanel({
    super.key,
    this.onOpenExercise,
    this.onOpenHistory,
    this.initialExerciseId,
    this.useSharedPeriod = false,
  });

  final ValueChanged<Exercise>? onOpenExercise;
  final ValueChanged<Exercise>? onOpenHistory;

  /// When set, only this exercise is shown, with 'Todo' selected initially.
  /// Used by the technical ficha's "Ver mi rendimiento" action.
  final String? initialExerciseId;

  /// True only inside the main Progreso tab. Standalone/focused routes keep
  /// their own "Todo" option for lifetime exercise exploration.
  final bool useSharedPeriod;

  @override
  ConsumerState<ProgressExercisesPanel> createState() =>
      _ProgressExercisesPanelState();
}

class _ProgressExercisesPanelState extends ConsumerState<ProgressExercisesPanel> {
  ProgressPeriod _period = ProgressPeriod.days90;
  ExerciseProgressOrder _order = ExerciseProgressOrder.recent;
  String? _muscle;
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialExerciseId != null) _period = ProgressPeriod.all;
  }

  @override
  Widget build(BuildContext context) {
    final analyticsCache = ref.watch(analytics.progressAnalyticsCacheProvider);
    final exercises = ref.watch(exerciseListProvider);
    final settings = ref.watch(settingsProvider);
    final sharedPeriod = widget.useSharedPeriod
        ? ref.watch(timeFilterProvider)
        : null;
    final clock = DateTime.now();
    // Round only the cache lookup window to the minute, not displayed dates.
    // This avoids a new analytics-cache entry on every search keystroke.
    // The exclusive upper bound is the next minute, so fresh workouts
    // recorded in this minute remain visible without accepting future days.
    final minute = DateTime(
      clock.year, clock.month, clock.day, clock.hour, clock.minute);
    final endExclusive = minute.add(const Duration(minutes: 1));
    // Selected Progreso tabs use the same 7D/1M/3M/1A duration.
    // Standalone/focused routes preserve 30/90/Todo local selection.
    final from = sharedPeriod != null
        ? sharedPeriod.startDateAt(minute)
        : _period.days == null
            ? null
            : minute.subtract(Duration(days: _period.days!));

    final entries = <_ProgressEntry>[];
    for (final exercise in exercises) {
      if (widget.initialExerciseId != null &&
          exercise.id != widget.initialExerciseId) {
        continue;
      }
      final trend = analyticsCache.trend(analytics.ExerciseAnalyticsRequest(
        exercise.id,
        period: analytics.ProgressPeriod(
          from: from,
          to: endExclusive,
          maxChartPoints: settings.performanceMode == PerformanceMode.savings
              ? 48 : 120,
        ),
      ));
      if (trend.hasRecordedWork) {
        entries.add(_ProgressEntry(exercise: exercise, trend: trend));
      }
    }
    final muscles = entries
        .map((entry) => entry.exercise.muscleGroup)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // A period change can remove the selected muscle from the available
    // groups. Fall back to "Todos" without keeping an invisible stale filter.
    final selectedMuscle = muscles.contains(_muscle) ? _muscle : null;
    final search = _search.trim().toLowerCase();
    final matching = entries.where((entry) =>
        entry.exercise.name.toLowerCase().contains(search) &&
        (selectedMuscle == null ||
            entry.exercise.muscleGroup == selectedMuscle))
        .toList();
    matching.sort((a, b) => compareExerciseProgress(
      order: _order,
      firstName: a.exercise.name,
      firstDate: a.trend.lastPerformedAt,
      firstChange: a.trend.latestComparison?.estimated1RmDelta,
      secondName: b.exercise.name,
      secondDate: b.trend.lastPerformedAt,
      secondChange: b.trend.latestComparison?.estimated1RmDelta,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Expanded(child: Text('Rendimiento por ejercicio',
                style: Theme.of(context).textTheme.titleMedium)),
            if (!widget.useSharedPeriod)
              DropdownButton<ProgressPeriod>(
              value: _period,
              items: ProgressPeriod.values.map((period) =>
                  DropdownMenuItem(value: period, child: Text(period.label)))
                  .toList(growable: false),
              onChanged: (period) {
                if (period != null) setState(() => _period = period);
              },
            ),
          ]),
        ),
        if (widget.useSharedPeriod)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ejercicios se atribuyen a la fecha de inicio de cada sesión.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (widget.initialExerciseId == null)
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(
            key: const ValueKey('progress_exercises_search'),
            decoration: const InputDecoration(
              labelText: 'Buscar ejercicio',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        if (widget.initialExerciseId == null)
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 62, child: Text('Orden')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<ExerciseProgressOrder>(
                      key: const ValueKey('progress_exercises_sort'),
                      isExpanded: true,
                      isDense: true,
                      value: _order,
                      items: [
                        for (final option in ExerciseProgressOrder.values)
                          DropdownMenuItem(
                            value: option,
                            child: Text(option.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (next) {
                        if (next != null) setState(() => _order = next);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 62, child: Text('Músculo')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String?>(
                      key: const ValueKey('progress_exercises_muscle'),
                      isExpanded: true,
                      isDense: true,
                      value: selectedMuscle,
                      hint: const Text('Todos'),
                      selectedItemBuilder: (context) => [
                        const Text('Todos', overflow: TextOverflow.ellipsis),
                        for (final group in muscles)
                          Text(group, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null, child: Text('Todos los músculos')),
                        for (final group in muscles)
                          DropdownMenuItem<String?>(
                            value: group, child: Text(group)),
                      ],
                      onChanged: (selected) =>
                          setState(() => _muscle = selected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Todavía no hay series efectivas registradas en este período.',
                      textAlign: TextAlign.center)))
              : matching.isEmpty
                  ? const Center(child: Text('No hay ejercicios con ese nombre.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: matching.length,
                      itemBuilder: (context, index) {
                        final entry = matching[index];
                        // Query lifetime evidence only for visible cards.
                        // The analytics index caches this across list rebuilds.
                        // A filter-period peak is NOT an all-time PR.
                        final lifetime = analyticsCache.trend(
                          analytics.ExerciseAnalyticsRequest(
                            entry.exercise.id,
                            period: analytics.ProgressPeriod(
                              from: null,
                              to: endExclusive,
                              maxChartPoints: 48,
                            ),
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExerciseInsightCard(
                            entry: entry,
                            unit: settings.weightUnit,
                            historicalPeak: lifetime.bestRecorded1RM,
                            historicalPeakAt: lifetime.bestRecorded1RMAt,
                            onOpenExercise: widget.onOpenExercise,
                            onOpenHistory: widget.onOpenHistory,
                            initiallyExpanded: widget.initialExerciseId != null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ProgressEntry {
  const _ProgressEntry({required this.exercise, required this.trend});
  final Exercise exercise;
  final ExerciseProgressTrend trend;
}

class _ExerciseInsightCard extends StatelessWidget {
  const _ExerciseInsightCard({
    required this.entry,
    required this.unit,
    required this.historicalPeak,
    required this.historicalPeakAt,
    this.onOpenExercise,
    this.onOpenHistory,
    this.initiallyExpanded = false,
  });

  final _ProgressEntry entry;
  final WeightUnit unit;
  final double historicalPeak;
  final DateTime? historicalPeakAt;
  final ValueChanged<Exercise>? onOpenExercise;
  final ValueChanged<Exercise>? onOpenHistory;
  final bool initiallyExpanded;

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
    // Do not claim an e1RM trend when either observation has no estimate.
    final estimatedDelta = comparison != null &&
            comparison.latest.estimated1RM > 0 &&
            comparison.previous.estimated1RM > 0
        ? comparison.estimated1RmDelta
        : null;
    final unilateral = UnilateralProgressCalculator.fromTrend(trend);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('progress_exercise_${entry.exercise.id}'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const Icon(Icons.insights_rounded),
        title: Text(
          entry.exercise.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        // A closed card must answer when the exercise was trained and
        // whether the latest measured strength changed, at large text sizes.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_date(latest.date)} · ${latest.routineName.isEmpty ? 'Entrenamiento libre' : latest.routineName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              trend.current1RM > 0
                  ? 'Último e1RM: ${FitnessFormatter.formatWeight(trend.current1RM, unit)}'
                  : 'Última sesión sin e1RM',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              estimatedDelta == null
                  ? 'Sin comparación'
                  : 'Vs. anterior: ${_weightDelta(estimatedDelta, unit)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
                label: 'Último e1RM',
                value: FitnessFormatter.formatWeight(trend.current1RM, unit),
              ),
              if (historicalPeak > trend.current1RM + 0.005)
                Tooltip(
                  message: historicalPeakAt == null
                      ? 'Máximo registrado de este ejercicio'
                      : 'Mejor registro: ${_date(historicalPeakAt!)}',
                  child: _Metric(
                    label: 'Mejor e1RM histórico',
                    value: FitnessFormatter.formatWeight(historicalPeak, unit),
                  ),
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
          _SelectableExerciseTrend(trend: trend, unit: unit),
          if (trend.hasPlateauSignal) ...[
            const SizedBox(height: 10),
            const _InfoMessage(
              icon: Icons.info_outline_rounded,
              text:
                  'Señal informativa: las últimas tres estimaciones de 1RM están dentro de un rango aproximado del 2%. Observa técnica, recuperación y contexto antes de cambiar el plan.',
            ),
          ],
          // Legacy routes without navigation retain the session preview.
          // In mobile, the user opens the same records from the exercise ficha.
          if (onOpenExercise == null && onOpenHistory == null) ...[
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
          if (onOpenExercise != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onOpenExercise!(entry.exercise),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Técnica y ficha del ejercicio'),
              ),
            ),
          if (onOpenHistory != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('progress_open_history_${entry.exercise.id}'),
                onPressed: () => onOpenHistory!(entry.exercise),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Ver historial completo'),
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

/// One metric selected at a time, using the recorded time stamps and the
/// same color/text tokens as other Flutter charts. Missing RIR stays neutral.
class _SelectableExerciseTrend extends StatefulWidget {
  const _SelectableExerciseTrend({
    required this.trend,
    required this.unit,
  });
  final ExerciseProgressTrend trend;
  final WeightUnit unit;

  @override
  State<_SelectableExerciseTrend> createState() =>
      _SelectableExerciseTrendState();
}

class _SelectableExerciseTrendState extends State<_SelectableExerciseTrend> {
  ExerciseTrendMetric selected = ExerciseTrendMetric.estimatedOneRm;

  String _display(double value) => switch (selected) {
    ExerciseTrendMetric.weight || ExerciseTrendMetric.estimatedOneRm =>
      FitnessFormatter.formatWeight(value, widget.unit),
    ExerciseTrendMetric.repetitions => '${value.round()} reps',
    ExerciseTrendMetric.rir => value.toStringAsFixed(1),
  };

  @override
  Widget build(BuildContext context) {
    final points = selected.points(widget.trend);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<ExerciseTrendMetric>(
          key: const ValueKey('progress_exercise_trend_selector'),
          value: selected,
          isDense: true,
          items: [
            for (final metric in ExerciseTrendMetric.values)
              DropdownMenuItem(
                value: metric,
                child: Text(metric.label),
              ),
          ],
          onChanged: (next) {
            if (next != null) setState(() => selected = next);
          },
        ),
        const SizedBox(height: 8),
        if (points.isEmpty)
          Text(
            'Sin datos de ${selected.label} registrados',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          Semantics(
            label: 'Tendencia de ${selected.label}: '
                '${_display(points.first.value)} a '
                '${_display(points.last.value)}',
            child: SizedBox(
              height: 65,
              width: double.infinity,
              child: CustomPaint(
                key: const ValueKey('progress_exercise_trend_plot'),
                painter: _ExerciseTrendPainter(
                  points: points,
                  lineColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${_display(points.first.value)} → ${_display(points.last.value)}'
            ' · rango ${_display(points.map((e) => e.value).reduce(math.min))}'
            '–${_display(points.map((e) => e.value).reduce(math.max))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ExerciseTrendPainter extends CustomPainter {
  _ExerciseTrendPainter({required this.points, required this.lineColor});

  final List<ExerciseProgressPoint> points;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;
    const inset = 7.0;
    final dx = math.max(1.0, size.width - inset * 2);
    final dy = math.max(1.0, size.height - inset * 2);
    final earliest = points.first.date.microsecondsSinceEpoch;
    final latest = points.last.date.microsecondsSinceEpoch;
    final sameTimestamp = earliest == latest;
    final low = points.map((p) => p.value).reduce(math.min);
    final high = points.map((p) => p.value).reduce(math.max);
    final sameValue = (high - low).abs() < 1e-9;

    Offset at(int index) {
      final p = points[index];
      final x = sameTimestamp
          ? (points.length == 1 ? 0.5 : index / (points.length - 1))
          : (p.date.microsecondsSinceEpoch - earliest) / (latest - earliest);
      final y = sameValue ? 0.5 : (p.value - low) / (high - low);
      return Offset(inset + x * dx, inset + (1 - y) * dy);
    }

    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final dots = Paint()..color = lineColor;
    if (points.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, line);
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 3.4, dots);
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseTrendPainter old) =>
      old.lineColor != lineColor || old.points != points;
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
