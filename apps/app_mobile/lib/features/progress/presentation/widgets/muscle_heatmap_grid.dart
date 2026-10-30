import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:gym_tracker/features/progress/presentation/pages/anatomy_audit_page.dart';
import 'package:core/features/progress/application/muscle_balance_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Kept under the historical name for navigation/backup compatibility.
/// All muscle analytics now live in this single Balance Muscular tab.
class MuscleHeatmapGrid extends ConsumerStatefulWidget {
  const MuscleHeatmapGrid({super.key});

  @override
  ConsumerState<MuscleHeatmapGrid> createState() => _MuscleHeatmapGridState();
}

class _MuscleHeatmapGridState extends ConsumerState<MuscleHeatmapGrid> {
  bool _showIndirect = false;
  bool _showInactive = false;

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

    final activeGroups = report.groups.where((g) => g.directSets > 0).toList();
    final inactiveGroups = report.groups.where((g) => g.directSets == 0).toList();
    final colors = AppColors.of(context);
    final maxSets = report.groups.fold<int>(
      0, (highest, group) => group.directSets > highest
          ? group.directSets : highest,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance muscular', style: AppTypography.headlineLarge),
              const SizedBox(height: 4),
              Text('Series efectivas por grupo',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary)),
            ],
          )),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Período elegido en Resumen',
            child: Container(
              key: const ValueKey('muscle_shared_period'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primaryFaded,
                borderRadius: BorderRadius.circular(22)),
              child: Text(period.label,
                style: AppTypography.labelLarge.copyWith(
                  color: colors.primary)),
            ),
          ),
        ]),
        const SizedBox(height: 7),
        Text('El período se cambia en Resumen. Los datos reflejan '
          'trabajo registrado, no crecimiento muscular ni recuperación.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary)),
        const SizedBox(height: 14),
        _SummaryCard(
          total: report.totalDirectSets,
          active: activeGroups.length,
          inactive: inactiveGroups.length,
        ),
        if (report.groups.any((group) =>
            group.canonicalGroupId == null &&
            (group.directSets > 0 || group.estimatedSecondarySets > 0))) ...[
          const SizedBox(height: 10),
          const Text(
            'Hay etiquetas antiguas por clasificar. Se muestran por separado '
            'sin asignarlas a un músculo específico ni alterar tus registros.',
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Distribución muscular',
            style: AppTypography.headlineMedium)),
          TextButton.icon(
            key: const ValueKey('open_anatomy_audit'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AnatomyAuditPage())),
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: const Text('Revisar historial'),
          ),
        ]),
        Text('Ordenado por series directas; barra relativa al grupo '
          'más trabajado.', style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.surfaceBorder),
            borderRadius: AppRadius.md_),
          child: SwitchListTile.adaptive(
            key: const ValueKey('muscle_indirect_toggle'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('Mostrar trabajo indirecto'),
            subtitle: const Text(
              'Secundarios estimados a 0,5 por serie; no se suman al directo.'),
            value: _showIndirect,
            activeThumbColor: colors.primary,
            onChanged: (value) => setState(() => _showIndirect = value),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('muscle_week_comparison'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: AppRadius.md_),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Semanas completas',
                  style: AppTypography.bodyMedium),
                Text('Independiente del período',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary)),
              ],
            )),
            Text('${DateFormat('dd/MM').format(report.previousWeekStart)}'
              ' → ${DateFormat('dd/MM').format(report.recentWeekStart)}',
              style: AppTypography.labelMedium.copyWith(
                color: colors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Grupos trabajados',
            style: AppTypography.headlineMedium)),
          Text('${activeGroups.length}',
            style: AppTypography.monoMedium.copyWith(
              color: colors.primary)),
        ]),
        const SizedBox(height: 9),
        if (report.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text(
              'No hay grupos musculares identificados. '
              'Añade ejercicios para construir tu balance.',
              textAlign: TextAlign.center)))
        else ...[
          if (!report.hasRecordedWork)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Aún no hay series efectivas en este período. '
                'Cambia el filtro desde Resumen para ver otro período.')),
          for (final muscle in activeGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _MuscleCard(
                key: ValueKey('muscle_${muscle.name.toLowerCase()}'),
                muscle: muscle,
                maxSets: maxSets,
                showIndirect: _showIndirect)),
          if (inactiveGroups.isNotEmpty) ...[
            OutlinedButton.icon(
              key: const ValueKey('muscle_inactive_toggle'),
              onPressed: () => setState(() => _showInactive = !_showInactive),
              icon: Icon(_showInactive
                ? Icons.expand_less : Icons.expand_more),
              label: Text(_showInactive
                ? 'Ocultar grupos sin trabajo (${inactiveGroups.length})'
                : 'Ver grupos sin trabajo (${inactiveGroups.length})'),
            ),
            if (_showInactive) ...[
              const SizedBox(height: 8),
              for (final muscle in inactiveGroups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _MuscleCard(
                    key: ValueKey('muscle_${muscle.name.toLowerCase()}'),
                    muscle: muscle,
                    maxSets: maxSets,
                    showIndirect: _showIndirect)),
            ],
          ],
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
    required this.total, required this.active, required this.inactive,
  });
  final int total;
  final int active;
  final int inactive;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('muscle_summary'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.surfaceBorder),
        borderRadius: AppRadius.lg_),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Metric(label: 'Series directas',
          value: '$total', prominent: true)),
        Container(height: 52, width: 1, color: colors.surfaceBorder),
        Expanded(child: _Metric(label: 'Trabajados', value: '$active')),
        Container(height: 52, width: 1, color: colors.surfaceBorder),
        Expanded(child: _Metric(label: 'Sin actividad', value: '$inactive')),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value,
    this.prominent = false});
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppTypography.headlineLarge.copyWith(
          color: prominent ? colors.primary : colors.textPrimary)),
        const SizedBox(height: 3),
        Text(label, maxLines: 2,
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary)),
      ]),
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    super.key, required this.muscle, required this.maxSets,
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
    final colors = AppColors.of(context);
    final contribution = muscle.directExerciseSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final unclassified = muscle.canonicalGroupId == null;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md_,
        side: BorderSide(color: colors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('muscle_details_${muscle.name.toLowerCase()}'),
        tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: colors.primary,
        collapsedIconColor: colors.textSecondary,
        title: Row(children: [
          Expanded(child: Text(
            unclassified ? '${muscle.name} · por clasificar' : muscle.name,
            maxLines: 2,
            style: AppTypography.headlineSmall.copyWith(
              color: colors.textPrimary))),
          const SizedBox(width: 7),
          Text('${muscle.directSets}',
            style: AppTypography.monoLarge.copyWith(
              color: muscle.directSets == 0
                ? colors.textSecondary : colors.primary)),
          const SizedBox(width: 4),
          Text('series', style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: maxSets <= 0 ? 0 : muscle.directSets / maxSets,
                minHeight: 6,
                backgroundColor: colors.primary.withValues(alpha: 0.11),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 7),
              Text('${muscle.trainingDays} días con actividad',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary)),
              if (showIndirect && muscle.estimatedSecondarySets > 0) ...[
                const SizedBox(height: 4),
                Text('Indirecto estimado: '
                  '${muscle.estimatedSecondarySets.toStringAsFixed(1)} '
                  'series equivalentes (separado)',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary)),
              ],
            ],
          ),
        ),
        children: [
          Divider(height: 14, color: colors.surfaceBorder),
          if (unclassified) ...[
            const _MuscleDetailRow(
              label: 'Clasificación',
              value: 'Etiqueta histórica sin equivalencia segura'),
            const SizedBox(height: 10),
          ],
          _MuscleDetailRow(
            label: 'Último trabajo',
            value: _date(muscle.lastTrainedAt)),
          const SizedBox(height: 9),
          _MuscleDetailRow(
            label: 'Semanas completas',
            value: '${muscle.previousFullWeekSets}'
              ' → ${muscle.recentFullWeekSets} series'),
          const SizedBox(height: 6),
          _MuscleDetailRow(
            label: 'Frecuencia',
            value: '${muscle.previousFullWeekDays}'
              ' → ${muscle.recentFullWeekDays} días/sem.'),
          if (muscle.plannedSetsInPerformedSessions != null) ...[
            const SizedBox(height: 10),
            _MuscleDetailRow(
              label: 'Realizado / plan actual',
              value: '${muscle.completedSetsInPlannedExercises}'
                '/${muscle.plannedSetsInPerformedSessions} series'),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ejercicios que aportaron trabajo directo',
              style: AppTypography.labelLarge.copyWith(
                color: colors.textPrimary)),
          ),
          const SizedBox(height: 6),
          if (contribution.isEmpty)
            Align(alignment: Alignment.centerLeft,
              child: Text('Ninguno en este período.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary)))
          else
            for (final item in contribution)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(item.key,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary))),
                  const SizedBox(width: 10),
                  Text('${item.value} series',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary)),
                ]),
              ),
        ],
      ),
    );
  }
}

class _MuscleDetailRow extends StatelessWidget {
  const _MuscleDetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label,
        style: AppTypography.bodySmall.copyWith(
          color: colors.textSecondary))),
      const SizedBox(width: 10),
      Flexible(child: Text(value, textAlign: TextAlign.end,
        style: AppTypography.bodySmall.copyWith(
          color: colors.textPrimary, fontWeight: FontWeight.w600))),
    ]);
  }
}
