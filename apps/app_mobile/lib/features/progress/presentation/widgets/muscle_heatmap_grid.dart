import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/progress/application/muscle_balance_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Kept under the historical name for navigation/backup compatibility.
/// All muscle analytics now live in this single Balance Muscular tab.
class MuscleHeatmapGrid extends ConsumerStatefulWidget {
  const MuscleHeatmapGrid({super.key});

  @override
  ConsumerState<MuscleHeatmapGrid> createState() => _MuscleHeatmapGridState();
}

class _MuscleHeatmapGridState extends ConsumerState<MuscleHeatmapGrid> {
  bool _showIndirect = false;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);
    final exercises = ref.watch(exerciseListProvider);
    final routines = ref.watch(routineListProvider);
    final period = ref.watch(timeFilterProvider);
    final report = MuscleBalanceCalculator.calculate(
      history: history,
      exercises: exercises,
      routines: routines,
      from: period.startDate,
      now: DateTime.now(),
    );

    final maxSets = report.groups.fold<int>(
      0, (highest, group) => group.directSets > highest
          ? group.directSets : highest,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        Text('Balance muscular',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        const Text(
          'Distribución de trabajo registrado, no una medición de crecimiento muscular ni de recuperación.',
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<TimeFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TimeFilter.week, label: Text('7D')),
              ButtonSegment(value: TimeFilter.month, label: Text('1M')),
              ButtonSegment(value: TimeFilter.threeMonths, label: Text('3M')),
              ButtonSegment(value: TimeFilter.year, label: Text('1A')),
            ],
            selected: {period},
            onSelectionChanged: (value) =>
                ref.read(timeFilterProvider.notifier).setFilter(value.first),
          ),
        ),
        const SizedBox(height: 14),
        _SummaryCard(
          total: report.totalDirectSets,
          active: report.groups.where((g) => g.directSets > 0).length,
          inactive: report.groups.where((g) => g.directSets == 0).length,
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          key: const ValueKey('muscle_indirect_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar trabajo indirecto estimado'),
          subtitle: const Text(
            'Los secundarios se estiman con 0,5 por serie usando el catálogo actual. No se suman a las series directas.',
          ),
          value: _showIndirect,
          onChanged: (value) => setState(() => _showIndirect = value),
        ),
        const SizedBox(height: 12),
        Text('Semanas completas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Comparación independiente del filtro: '
          '${DateFormat('dd/MM').format(report.previousWeekStart)} vs. '
          '${DateFormat('dd/MM').format(report.recentWeekStart)} '
          '(lunes a domingo). La semana actual no cuenta.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 15),
        if (report.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text(
              'No hay grupos musculares identificados. '
              'Añade ejercicios para construir tu balance.',
              textAlign: TextAlign.center,
            )),
          )
        else ...[
          if (!report.hasRecordedWork)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Aún no hay series efectivas en este período. '
                'Los grupos conocidos aparecen con cero actividad.',
              ),
            ),
          for (final muscle in report.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MuscleCard(
                key: ValueKey('muscle_${muscle.name.toLowerCase()}'),
                muscle: muscle,
                maxSets: maxSets,
                showIndirect: _showIndirect,
              ),
            ),
        ],
        if (report.sessionsWithComparablePlan > 0) ...[
          const SizedBox(height: 9),
          const Text(
            'Plan vs. realizado: solo sesiones ya registradas con una '
            'rutina que todavía existe. Los objetivos se leen de la '
            'versión actual de esa rutina; podrían diferir de los '
            'objetivos originales. No incluye sesiones que no se iniciaron.',
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.active,
    required this.inactive,
  });

  final int total;
  final int active;
  final int inactive;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          _Metric(label: 'Series directas', value: '$total'),
          _Metric(label: 'Grupos trabajados', value: '$active'),
          _Metric(label: 'Sin trabajo directo', value: '$inactive'),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    super.key,
    required this.muscle,
    required this.maxSets,
    required this.showIndirect,
  });
  final MuscleBalanceItem muscle;
  final int maxSets;
  final bool showIndirect;

  String _date(DateTime? value) => value == null
      ? 'Sin registros'
      : DateFormat('dd/MM/yyyy').format(value.toLocal());

  @override
  Widget build(BuildContext context) {
    final contribution = muscle.directExerciseSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('muscle_details_${muscle.name.toLowerCase()}'),
        title: Text(muscle.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              '${muscle.directSets} series directas · '
              '${muscle.trainingDays} días con actividad',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: maxSets <= 0 ? 0 : muscle.directSets / maxSets,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
            ),
            if (showIndirect && muscle.estimatedSecondarySets > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Indirecto estimado: '
                '${muscle.estimatedSecondarySets.toStringAsFixed(1)} '
                'series equivalentes (separado)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Último trabajo: ${_date(muscle.lastTrainedAt)}'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Semanas completas (anterior → reciente): '
              '${muscle.previousFullWeekSets} → '
              '${muscle.recentFullWeekSets} series directas',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Frecuencia: ${muscle.previousFullWeekDays} → '
              '${muscle.recentFullWeekDays} días por semana',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (muscle.plannedSetsInPerformedSessions != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'En sesiones con rutina: '
                '${muscle.completedSetsInPlannedExercises}/'
                '${muscle.plannedSetsInPerformedSessions} '
                'series efectivas realizadas/planificadas',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ejercicios que aportaron trabajo directo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (contribution.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ninguno en este período.'),
            )
          else
            for (final item in contribution)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.key),
                trailing: Text('${item.value} series'),
              ),
        ],
      ),
    );
  }
}
