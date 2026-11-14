import 'dart:math' as math;
import 'dart:ui' show FontFeature;

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
import 'package:core/features/progress/presentation/widgets/compact_progress_period_selector.dart';
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
    this.onOpenPerformance,
    this.initialExerciseId,
    this.useSharedPeriod = false,
  });

  final ValueChanged<Exercise>? onOpenExercise;
  final ValueChanged<Exercise>? onOpenHistory;
  /// Dedicated detailed chart route; the main list stays compact.
  final ValueChanged<Exercise>? onOpenPerformance;

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
  bool _filtersExpanded = false;
  bool _compactSearchOpen = false;
  bool _showAllHistory = false;
  final TextEditingController _compactSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialExerciseId != null) _period = ProgressPeriod.all;
    // Main Progreso uses a compact filter drawer; keep standalone routes'
    // filters visible to preserve their established controls.
    _filtersExpanded =
        !widget.useSharedPeriod && widget.initialExerciseId == null;
  }

  @override
  void dispose() {
    _compactSearchController.dispose();
    super.dispose();
  }

  Future<void> _openCompactFilters(List<String> muscles) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 6, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.73,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Filtrar ejercicios',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    const Text('Ordenar por'),
                    DropdownButton<ExerciseProgressOrder>(
                      key: const ValueKey('progress_exercises_sort'),
                      isExpanded: true,
                      value: _order,
                      items: [
                        for (final option in ExerciseProgressOrder.values)
                          DropdownMenuItem(
                            value: option,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _order = value);
                        updateSheet(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Grupo muscular'),
                    DropdownButton<String?>(
                      key: const ValueKey('progress_exercises_muscle'),
                      isExpanded: true,
                      value: muscles.contains(_muscle) ? _muscle : null,
                      hint: const Text('Todos'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null, child: Text('Todos los músculos')),
                        for (final group in muscles)
                          DropdownMenuItem<String?>(
                            value: group,
                            child: Text(group, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _muscle = value);
                        updateSheet(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      key: const ValueKey('progress_exercises_all_history'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ver todos los ejercicios con historial'),
                      subtitle: const Text(
                        'Busca sesiones antiguas sin cambiar el período compartido.'),
                      value: _showAllHistory,
                      onChanged: (value) {
                        setState(() {
                          _showAllHistory = value;
                          if (value) _muscle = null;
                        });
                        updateSheet(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _order = ExerciseProgressOrder.recent;
                              _muscle = null;
                              _showAllHistory = false;
                            });
                            updateSheet(() {});
                          },
                          child: const Text('Restablecer'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Ver ejercicios'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
        ? (_showAllHistory ? null : sharedPeriod.startDateAt(minute))
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
        if (widget.useSharedPeriod && widget.initialExerciseId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text('Tus ejercicios',
                      style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('progress_exercises_search_toggle'),
                          tooltip: _compactSearchOpen
                              ? 'Cerrar búsqueda'
                              : 'Buscar ejercicio',
                          onPressed: () =>
                              setState(() => _compactSearchOpen = !_compactSearchOpen),
                          icon: Icon(_compactSearchOpen
                              ? Icons.close_rounded : Icons.search_rounded,
                            color: _search.isNotEmpty
                                ? Theme.of(context).colorScheme.primary : null),
                        ),
                        IconButton(
                          key: const ValueKey('progress_exercises_toggle_filters'),
                          tooltip: 'Filtros de ejercicios',
                          onPressed: () => _openCompactFilters(muscles),
                          icon: Badge(
                            isLabelVisible: _order != ExerciseProgressOrder.recent ||
                                selectedMuscle != null || _showAllHistory,
                            smallSize: 7,
                            child: const Icon(Icons.tune_rounded),
                          ),
                        ),
                        const CompactProgressPeriodSelector(),
                      ],
                    ),
                  ],
                ),
                if (_compactSearchOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: TextField(
                      key: const ValueKey('progress_exercises_search'),
                      controller: _compactSearchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar ejercicio',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _compactSearchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      onChanged: (text) => setState(() => _search = text),
                    ),
                  ),
                if (_showAllHistory)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Historial completo · no cambia el período de otras pestañas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          )
        else if (widget.initialExerciseId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Rendimiento por ejercicio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.useSharedPeriod)
                  Tooltip(
                    message: 'Los registros se atribuyen a la fecha de inicio de cada sesión.',
                    child: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const ValueKey('progress_exercises_toggle_filters'),
                  onPressed: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  icon: Icon(_filtersExpanded
                      ? Icons.filter_alt_off_outlined
                      : Icons.tune_rounded),
                  label: Text(_filtersExpanded ? 'Ocultar' : 'Filtros'),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Evolución y sesiones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<ProgressPeriod>(
                  value: _period,
                  isDense: true,
                  items: [
                    for (final period in ProgressPeriod.values)
                      DropdownMenuItem(
                        value: period,
                        child: Text(period.label),
                      ),
                  ],
                  onChanged: (period) {
                    if (period != null) setState(() => _period = period);
                  },
                ),
              ],
            ),
          ),
        if (widget.initialExerciseId == null && !widget.useSharedPeriod)
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
        if (widget.initialExerciseId == null &&
            !widget.useSharedPeriod && _filtersExpanded)
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
                            onOpenPerformance: widget.onOpenPerformance,
                            compact: widget.useSharedPeriod &&
                                widget.initialExerciseId == null &&
                                widget.onOpenPerformance != null,
                            initiallyExpanded: widget.initialExerciseId != null,
                            permanentlyExpanded: widget.initialExerciseId != null,
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
    this.onOpenPerformance,
    this.compact = false,
    this.initiallyExpanded = false,
    this.permanentlyExpanded = false,
  });

  final _ProgressEntry entry;
  final WeightUnit unit;
  final double historicalPeak;
  final DateTime? historicalPeakAt;
  final ValueChanged<Exercise>? onOpenExercise;
  final ValueChanged<Exercise>? onOpenHistory;
  final ValueChanged<Exercise>? onOpenPerformance;
  final bool compact;
  final bool initiallyExpanded;
  final bool permanentlyExpanded;

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

    // The main Progreso list is a directory, not a second performance page.
    // Keep full charts, dates, records and history in the focused route.
    if (compact) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: ValueKey('progress_exercise_${entry.exercise.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
          onTap: onOpenPerformance == null
              ? null
              : () => onOpenPerformance!(entry.exercise),
          leading: const Icon(Icons.insights_outlined),
          title: Text(
            entry.exercise.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            '${_date(latest.date)} · '
            '${trend.current1RM > 0 ? FitnessFormatter.formatWeight(trend.current1RM, unit) : 'Sin e1RM'}',
            maxLines: 2,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    }

    // The focused route has exactly one exercise: its data must never collapse.
    // Legacy multi-card contexts retain ExpansionTile behavior.
    final details = <Widget>[

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

          // The chart is the primary task of this screen: show it BEFORE
          // secondary PR/compare tiles so it can be reached immediately.
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
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: permanentlyExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: ValueKey('progress_exercise_${entry.exercise.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: details,
                  ),
                ),
              ],
            )
          : ExpansionTile(
              key: ValueKey('progress_exercise_${entry.exercise.id}'),
              initiallyExpanded: initiallyExpanded,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 4),
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
              children: details,
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


/* A full-size, selectable session chart. The latest session is selected
 * initially; touches and a date picker expose all four recorded metrics. */
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
  String? _selectedSessionId;
  String? _lastAlignedSessionId;
  final ScrollController _chartScroll = ScrollController();

  @override
  void dispose() {
    _chartScroll.dispose();
    super.dispose();
  }

  double? _value(ExerciseSessionPerformance session) => switch (selected) {
    ExerciseTrendMetric.weight => session.bestWeight,
    ExerciseTrendMetric.repetitions => session.bestReps.toDouble(),
    ExerciseTrendMetric.rir => session.averageRir,
    ExerciseTrendMetric.estimatedOneRm =>
      session.estimated1RM > 0 ? session.estimated1RM : null,
  };

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _sessionLabel(ExerciseSessionPerformance session) {
    final local = session.date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final name = session.routineName.isEmpty
        ? 'Entrenamiento libre'
        : session.routineName;
    return '${_date(session.date)} · $hour:$minute · $name';
  }

  String _weight(double value) =>
      FitnessFormatter.formatWeight(value, widget.unit)
          .replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final sessions = widget.trend.sessions;
    if (sessions.isEmpty) {
      return const Text('No hay sesiones con series efectivas');
    }

    // Session IDs remain stable after switching metric/period.
    final selectedId = sessions.any(
      (s) => s.sessionId == _selectedSessionId,
    ) ? _selectedSessionId! : sessions.last.sessionId;
    final detail = sessions.firstWhere((s) => s.sessionId == selectedId);
    // Missing RIR is NOT zero; never fabricate a chart point.
    final plotted = sessions.where((s) => _value(s) != null).toList();
    final values = plotted.map((s) => ExerciseProgressPoint(
      date: s.date, value: _value(s)!,
    )).toList(growable: false);
    final highlight = plotted.indexWhere((s) => s.sessionId == selectedId);
    final scheme = Theme.of(context).colorScheme;
    final scale =
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Métrica del gráfico',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        DropdownButton<ExerciseTrendMetric>(
          key: const ValueKey('progress_exercise_trend_selector'),
          value: selected,
          isExpanded: true,
          items: [
            for (final metric in ExerciseTrendMetric.values)
              DropdownMenuItem(
                value: metric,
                child: Text(metric.label),
              ),
          ],
          onChanged: (next) {
            if (next != null) {
              setState(() {
                selected = next;
                _lastAlignedSessionId = null;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        if (plotted.isEmpty)
          Text(
            'Sin datos de ${selected.label} registrados',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...[
          Text(
            'Toca un punto o selecciona una sesión para consultar sus valores.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = math.max(
                constraints.maxWidth,
                math.max(1, values.length - 1) * 44.0 + 48,
              );
              // Align once per selected session, after scroll dimensions are
              // known. This makes the newest point visible instead of clipping
              // it at the right edge of the viewport.
              if (highlight >= 0 && _lastAlignedSessionId != selectedId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_chartScroll.hasClients) return;
                  const inset = 24.0;
                  final x = values.length == 1 ? chartWidth / 2
                      : inset + (chartWidth - 2 * inset) *
                          highlight / (values.length - 1);
                  final target = (x - constraints.maxWidth + 30.0)
                      .clamp(0.0, _chartScroll.position.maxScrollExtent)
                      .toDouble();
                  _chartScroll.jumpTo(target);
                  _lastAlignedSessionId = selectedId;
                });
              }
              return SingleChildScrollView(
                controller: _chartScroll,
                scrollDirection: Axis.horizontal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) {
                    final index = values.length == 1
                        ? 0
                        : (((event.localPosition.dx - 24) /
                              (chartWidth - 48)) * (values.length - 1))
                            .round().clamp(0, values.length - 1).toInt();
                    setState(() =>
                        _selectedSessionId = plotted[index].sessionId);
                  },
                  child: Semantics(
                    label: 'Gráfico de ${selected.label} por sesión. '
                        'Puedes tocar los puntos o elegir la fecha '
                        'en el selector inferior.',
                    child: SizedBox(
                      width: chartWidth,
                      height: 180,
                      child: CustomPaint(
                        key: const ValueKey('progress_exercise_trend_plot'),
                        painter: _ExerciseTrendPainter(
                          points: values,
                          selectedPointIndex: highlight,
                          lineColor: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          // Dates must wrap at 320px / 160% text, not overflow by 110px.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(_date(plotted.first.date),
                  style: Theme.of(context).textTheme.labelSmall),
              Text(_date(plotted.last.date),
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('Sesión seleccionada',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButton<String>(
          key: const ValueKey('progress_exercise_session_selector'),
          value: selectedId,
          isExpanded: true,
          items: [
            for (final session in sessions.reversed)
              DropdownMenuItem(
                value: session.sessionId,
                child: Text(
                  _sessionLabel(session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) setState(() => _selectedSessionId = id);
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                constraints.maxWidth >= (148.0 * scale * 2 + 8);
            final tileWidth = twoColumns
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _SessionValueTile(
                    label: 'Peso máximo',
                    value: _weight(detail.bestWeight),
                    key: const ValueKey('progress_session_weight'),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _SessionValueTile(
                    label: 'Repeticiones',
                    value: '${detail.bestReps}',
                    key: const ValueKey('progress_session_reps'),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _SessionValueTile(
                    label: 'RIR medio',
                    value: detail.averageRir == null
                        ? 'Sin registrar'
                        : detail.averageRir!.toStringAsFixed(1)
                            .replaceAll('.', ','),
                    key: const ValueKey('progress_session_rir'),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _SessionValueTile(
                    label: 'e1RM máximo',
                    value: detail.estimated1RM > 0
                        ? _weight(detail.estimated1RM)
                        : 'Sin estimación',
                    key: const ValueKey('progress_session_e1rm'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Resumen de la sesión · ${detail.completedWorkingSets} '
          '${detail.completedWorkingSets == 1 ? 'serie efectiva' : 'series efectivas'}. '
          'El historial muestra cada serie individual.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SessionValueTile extends StatelessWidget {
  const _SessionValueTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                softWrap: true,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseTrendPainter extends CustomPainter {
  _ExerciseTrendPainter({
    required this.points,
    required this.lineColor,
    this.selectedPointIndex = -1,
  });

  final List<ExerciseProgressPoint> points;
  final Color lineColor;
  final int selectedPointIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;
    const inset = 24.0;
    final dx = math.max(1.0, size.width - inset * 2);
    final dy = math.max(1.0, size.height - inset * 2);
    final low = points.map((p) => p.value).reduce(math.min);
    final high = points.map((p) => p.value).reduce(math.max);
    final sameValue = (high - low).abs() < 1e-9;

    Offset at(int index) {
      final x = points.length == 1 ? 0.5 : index / (points.length - 1);
      final y = sameValue ? 0.5 : (points[index].value - low) / (high - low);
      return Offset(inset + x * dx, inset + (1 - y) * dy);
    }

    final guideline = Paint()
      ..color = lineColor.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (final level in [0.0, .5, 1.0]) {
      canvas.drawLine(
        Offset(inset, inset + dy * level),
        Offset(size.width - inset, inset + dy * level),
        guideline,
      );
    }
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final dots = Paint()..color = lineColor;
    if (points.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, stroke);
    }
    if (selectedPointIndex >= 0 && selectedPointIndex < points.length) {
      final p = at(selectedPointIndex);
      canvas.drawLine(Offset(p.dx, inset),
          Offset(p.dx, size.height - inset), guideline);
    }
    for (var i = 0; i < points.length; i++) {
      final focused = i == selectedPointIndex;
      final point = at(i);
      canvas.drawCircle(point, focused ? 7.5 : 4.3, dots);
      if (focused) {
        canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseTrendPainter old) =>
      old.lineColor != lineColor ||
      old.selectedPointIndex != selectedPointIndex ||
      old.points != points;
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
