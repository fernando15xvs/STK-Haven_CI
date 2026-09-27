import 'dart:async';

import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/programs/application/program_plan_insights.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_volume_planner.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _friendlyProgramName(String value) {
  return value == 'Upper / Lower (4 Días)'
      ? 'Upper / Lower continuo'
      : value;
}

String _friendlyProgramNote(String value) {
  final note = value.trim();
  if (note.startsWith('Instalado desde onboarding ·')) {
    return 'Programa recomendado según tu configuración inicial.';
  }
  return note;
}

String _weekdayAndDate(DateTime value) {
  const weekdays = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };
  return '${weekdays[value.weekday]} · ${value.day}/${value.month}';
}

class TrainingProgramsPage extends ConsumerStatefulWidget {
  const TrainingProgramsPage({super.key});

  @override
  ConsumerState<TrainingProgramsPage> createState() =>
      _TrainingProgramsPageState();
}

class _TrainingProgramsPageState extends ConsumerState<TrainingProgramsPage> {
  bool _reconcileScheduled = false;

  @override
  Widget build(BuildContext context) {
    if (!_reconcileScheduled) {
      _reconcileScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(trainingProgramListProvider.notifier).reconcileActive(),
        );
      });
    }
    final programs = ref.watch(trainingProgramListProvider);
    final routines = ref.watch(routineListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final exercises = ref.watch(exerciseListProvider);
    final routineById = <String, Routine>{
      for (final routine in routines) routine.id: routine,
    };
    final muscleByExercise = <String, String>{
      for (final exercise in exercises) exercise.id: exercise.muscleGroup,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de entrenamiento'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: routines.isEmpty
            ? null
            : () => _showEditor(context, ref, routines, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo plan'),
      ),
      body: programs.isEmpty
          ? _EmptyPrograms(hasRoutines: routines.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                final weekStart = _startOfWeek(DateTime.now());
                final plannedSessions = ProgramScheduleProjector.projectWeek(
                  program: program,
                  routines: routines,
                  weekStart: weekStart,
                );
                final volumes = ProgramVolumePlanner.calculateWeek(
                  program: program,
                  routines: routines,
                  history: history,
                  muscleGroupByExerciseId: muscleByExercise,
                  weekStart: weekStart,
                );
                final insights = ProgramPlanInsights.calculate(
                  program: program,
                  routines: routines,
                  now: DateTime.now(),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProgramCard(
                    program: program,
                    routineById: routineById,
                    volumes: volumes,
                    plannedSessions: plannedSessions,
                    insights: insights,
                    onActivate: () => ref
                        .read(trainingProgramListProvider.notifier)
                        .activate(program.id),
                    onEdit: () =>
                        _showEditor(context, ref, routines, program),
                    onDuplicate: () => ref
                        .read(trainingProgramListProvider.notifier)
                        .duplicate(program.id),
                    onSaveTemplate: program.isTemplate
                        ? null
                        : () => ref
                            .read(trainingProgramListProvider.notifier)
                            .saveAsTemplate(program.id),
                    onUseTemplate: program.isTemplate
                        ? () => ref
                            .read(trainingProgramListProvider.notifier)
                            .createFromTemplate(program.id)
                        : null,
                    onPause: program.isActive && !program.isTemplate
                        ? () => ref
                            .read(trainingProgramListProvider.notifier)
                            .pause(program.id)
                        : null,
                    onResume: !program.isActive && !program.isTemplate
                        ? () => ref
                            .read(trainingProgramListProvider.notifier)
                            .resume(program.id)
                        : null,
                    onDelete: () => _confirmDelete(context, ref, program),
                  ),
                );
              },
            ),
    );
  }

  static DateTime _startOfWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref,
    List<Routine> routines,
    TrainingProgram? existing,
  ) async {
    final name = TextEditingController(
      text: existing == null ? 'Mi plan' : _friendlyProgramName(existing.name),
    );
    final notes = TextEditingController(
      text: existing == null ? '' : _friendlyProgramNote(existing.notes),
    );
    var durationWeeks = existing?.durationWeeks ?? 8;
    var routineIds = List<String>.from(existing?.routineIds ?? const []);
    var trainingWeekdays = existing == null
        ? <int>{}
        : ProgramScheduleProjector.effectiveTrainingWeekdays(existing, routines);
    var deloadWeeks = Set<int>.from(existing?.deloadWeeks ?? const {});
    final currentWeek = existing?.weekAt(DateTime.now()) ?? 1;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final byId = <String, Routine>{
            for (final routine in routines) routine.id: routine,
          };

          void move(int index, int direction) {
            final target = index + direction;
            if (target < 0 || target >= routineIds.length) return;
            setDialogState(() {
              final next = List<String>.from(routineIds);
              final value = next.removeAt(index);
              next.insert(target, value);
              routineIds = next;
            });
          }

          return AlertDialog(
            title: Text(existing == null ? 'Crear plan' : 'Editar plan'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: durationWeeks,
                      decoration: const InputDecoration(
                        labelText: 'Duración del mesociclo',
                      ),
                      items: const [4, 6, 8, 10, 12, 16, 20, 24]
                          .map(
                            (weeks) => DropdownMenuItem(
                              value: weeks,
                              child: Text('$weeks semanas'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => durationWeeks = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Días de entrenamiento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estos días indican cuándo entrenas. La rutina que toca sigue la secuencia y no se reinicia cada semana.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        (DateTime.monday, 'L'),
                        (DateTime.tuesday, 'M'),
                        (DateTime.wednesday, 'X'),
                        (DateTime.thursday, 'J'),
                        (DateTime.friday, 'V'),
                        (DateTime.saturday, 'S'),
                        (DateTime.sunday, 'D'),
                      ].map((entry) {
                        final day = entry.$1;
                        final label = entry.$2;
                        return FilterChip(
                          label: Text(label),
                          selected: trainingWeekdays.contains(day),
                          onSelected: (selected) => setDialogState(() {
                            final next = Set<int>.from(trainingWeekdays);
                            if (selected) {
                              next.add(day);
                            } else {
                              next.remove(day);
                            }
                            trainingWeekdays = next;
                          }),
                        );
                      }).toList(),
                    ),
                    if (trainingWeekdays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Sin días específicos: podrás iniciar la siguiente sesión cualquier día.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Semana $currentWeek de descarga'),
                      subtitle: const Text(
                        'Opcional y manual. No cambia la identidad de las rutinas.',
                      ),
                      value: deloadWeeks.contains(currentWeek),
                      onChanged: (enabled) {
                        setDialogState(() {
                          final next = Set<int>.from(deloadWeeks);
                          if (enabled) {
                            next.add(currentWeek);
                          } else {
                            next.remove(currentWeek);
                          }
                          deloadWeeks = next;
                        });
                      },
                    ),
                    const Divider(),
                    Text(
                      'Rotación',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La secuencia continúa entre semanas: por ejemplo Upper A → Lower A → Upper B → Lower B → Upper A…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (routineIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Añade al menos una rutina.'),
                      ),
                    ...List.generate(routineIds.length, (index) {
                      final routine = byId[routineIds[index]];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(routine?.name ?? 'Rutina eliminada'),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Subir',
                              onPressed:
                                  index == 0 ? null : () => move(index, -1),
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                            IconButton(
                              tooltip: 'Bajar',
                              onPressed: index == routineIds.length - 1
                                  ? null
                                  : () => move(index, 1),
                              icon: const Icon(Icons.arrow_downward_rounded),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed: () => setDialogState(() {
                                final next = List<String>.from(routineIds)
                                  ..removeAt(index);
                                routineIds = next;
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Añadir rutina'),
                      children: routines
                          .where((routine) => !routineIds.contains(routine.id))
                          .map(
                            (routine) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(routine.name),
                              trailing: const Icon(Icons.add_rounded),
                              onTap: () => setDialogState(() {
                                routineIds = [...routineIds, routine.id];
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    if (existing != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setDialogState(() {
                            durationWeeks += 1;
                            if (deloadWeeks.contains(currentWeek)) {
                              deloadWeeks.add(currentWeek + 1);
                            }
                          }),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Duplicar semana actual'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: routineIds.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(existing == null ? 'Crear y activar' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (save == true) {
      if (existing == null) {
        await ref.read(trainingProgramListProvider.notifier).create(
              name: name.text,
              routineIds: routineIds,
              durationWeeks: durationWeeks,
              trainingWeekdays: trainingWeekdays,
              deloadWeeks: deloadWeeks,
              notes: notes.text,
              activate: true,
            );
      } else {
        final safeNext = routineIds.isEmpty
            ? 0
            : existing.normalizedNextRotationIndex
                .clamp(0, routineIds.length - 1)
                .toInt();
        await ref.read(trainingProgramListProvider.notifier).save(
              existing.copyWith(
                name: name.text.trim().isEmpty
                    ? existing.name
                    : name.text.trim(),
                notes: notes.text.trim(),
                durationWeeks: durationWeeks,
                routineIds: routineIds,
                trainingWeekdays: trainingWeekdays,
                deloadWeeks: deloadWeeks,
                nextRotationIndex: safeNext,
              ),
            );
      }
    }

    name.dispose();
    notes.dispose();
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar plan'),
        content: Text(
          'Se eliminará “${program.name}”. Sus rutinas y entrenamientos históricos se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(trainingProgramListProvider.notifier)
          .delete(program.id);
    }
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.routineById,
    required this.volumes,
    required this.plannedSessions,
    required this.insights,
    required this.onActivate,
    required this.onEdit,
    required this.onDuplicate,
    required this.onSaveTemplate,
    required this.onUseTemplate,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  final TrainingProgram program;
  final Map<String, Routine> routineById;
  final List<ProgramMuscleVolume> volumes;
  final List<ProgramScheduledSession> plannedSessions;
  final ProgramPlanInsights insights;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onSaveTemplate;
  final VoidCallback? onUseTemplate;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = program.weekAt(now);
    final nextRoutine = program.nextRoutineId == null
        ? null
        : routineById[program.nextRoutineId!];
    final progress = program.durationWeeks <= 0
        ? 0.0
        : (week / program.durationWeeks).clamp(0.0, 1.0).toDouble();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  program.isActive
                      ? Icons.play_circle_fill_rounded
                      : Icons.layers_outlined,
                  color: program.isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friendlyProgramName(program.name),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        program.isTemplate
                            ? '${program.routineIds.length} rutinas · '
                                '${program.durationWeeks} semanas · reutilizable'
                            : '${program.routineIds.length} rutinas · '
                                'Semana $week/${program.durationWeeks} · '
                                '${program.completions.length} completadas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (program.isTemplate)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Chip(label: Text('Plantilla')),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'activate') return onActivate();
                    if (value == 'edit') return onEdit();
                    if (value == 'duplicate') return onDuplicate();
                    if (value == 'template') return onSaveTemplate?.call();
                    if (value == 'use_template') return onUseTemplate?.call();
                    if (value == 'pause') return onPause?.call();
                    if (value == 'resume') return onResume?.call();
                    if (value == 'delete') return onDelete();
                  },
                  itemBuilder: (context) => [
                    if (!program.isTemplate && !program.isActive)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Text('Activar'),
                      ),
                    if (onPause != null)
                      const PopupMenuItem(
                        value: 'pause',
                        child: Text('Pausar plan'),
                      ),
                    if (onResume != null)
                      const PopupMenuItem(
                        value: 'resume',
                        child: Text('Reanudar plan'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (!program.isTemplate)
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar plan'),
                      ),
                    if (onSaveTemplate != null)
                      const PopupMenuItem(
                        value: 'template',
                        child: Text('Guardar como plantilla'),
                      ),
                    if (onUseTemplate != null)
                      const PopupMenuItem(
                        value: 'use_template',
                        child: Text('Crear plan desde plantilla'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            if (!program.isTemplate) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 14),
              _PlanOverview(
                program: program,
                nextRoutine: nextRoutine,
                routineById: routineById,
                insights: insights,
              ),
            ] else ...[
              const SizedBox(height: 12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.library_books_outlined),
                title: Text('Plantilla reutilizable'),
                subtitle: Text(
                  'Al usarla se crea un programa nuevo con rotación e historial independientes.',
                ),
              ),
            ],
            if (_friendlyProgramNote(program.notes).isNotEmpty)
              Text(_friendlyProgramNote(program.notes)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Rotación y cumplimiento'),
              subtitle: Text(
                program.routineIds
                    .map((id) => routineById[id]?.name ?? 'Eliminada')
                    .join(' → '),
              ),
              children: [
                if (program.completions.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Aún no hay sesiones completadas.'),
                  )
                else
                  ...program.completions.reversed.take(8).map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.check_circle_outline_rounded),
                          title: Text(
                            routineById[item.routineId]?.name ?? item.routineId,
                          ),
                          subtitle: Text(
                            'Semana ${item.programWeek} · ${_date(item.completedAt)}',
                          ),
                        ),
                      ),
              ],
            ),
            if (plannedSessions.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Plan de esta semana'),
                subtitle: Text(
                  plannedSessions
                      .map(
                        (item) =>
                            routineById[item.routineId]?.name ?? 'Rutina eliminada',
                      )
                      .join(' → '),
                ),
                children: plannedSessions
                    .map(
                      (item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text(
                          routineById[item.routineId]?.name ??
                              'Rutina eliminada',
                        ),
                        subtitle: Text(_weekdayAndDate(item.date)),
                      ),
                    )
                    .toList(),
              ),
            if (insights.next14SessionCount > 0)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Próximos 14 días'),
                subtitle: Text(
                  '${insights.next14SessionCount} sesiones previstas · distribución por rutina',
                ),
                children: [
                  for (final routineId in program.routineIds)
                    if ((insights.next14RoutineCounts[routineId] ?? 0) > 0)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.repeat_rounded),
                        title: Text(
                          routineById[routineId]?.name ?? 'Rutina eliminada',
                        ),
                        trailing: Text(
                          '×${insights.next14RoutineCounts[routineId]}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                ],
              ),
            if (volumes.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Volumen de esta semana'),
                subtitle: const Text(
                  'Previsto según el calendario y la rotación continua vs realizado.',
                ),
                children: volumes
                    .map(
                      (volume) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(volume.muscleGroup),
                        subtitle: Text(
                          '${volume.completedWorkingSets}/${volume.plannedWorkingSets} series · ${volume.performedVolume.toStringAsFixed(0)}/${volume.plannedVolume.toStringAsFixed(0)} kg·rep',
                        ),
                        trailing: volume.completionRatio == null
                            ? null
                            : Text(
                                '${(volume.completionRatio! * 100).clamp(0, 999).toStringAsFixed(0)}%',
                              ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _PlanOverview extends StatelessWidget {
  const _PlanOverview({
    required this.program,
    required this.nextRoutine,
    required this.routineById,
    required this.insights,
  });

  final TrainingProgram program;
  final Routine? nextRoutine;
  final Map<String, Routine> routineById;
  final ProgramPlanInsights insights;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nextDate = insights.nextScheduledDate;
    final nextName = insights.nextScheduledRoutineId == null
        ? nextRoutine?.name
        : routineById[insights.nextScheduledRoutineId!]?.name ??
            nextRoutine?.name;
    final statusColor = insights.pendingDue > 0
        ? colors.error
        : colors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                insights.pendingDue > 0
                    ? Icons.schedule_rounded
                    : Icons.check_circle_outline_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insights.paceLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (program.isDeloadWeekAt(DateTime.now()))
                const Chip(label: Text('Descarga')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InsightMetric(
                icon: Icons.event_available_outlined,
                label: 'Esta semana',
                value:
                    '${insights.completedThisWeek}/${insights.plannedThisWeek} sesiones',
              ),
              _InsightMetric(
                icon: Icons.skip_next_rounded,
                label: 'Próxima',
                value: nextDate == null
                    ? 'Sin fecha'
                    : '${_shortDate(nextDate)} · ${nextName ?? 'Rutina'}',
              ),
              _InsightMetric(
                icon: Icons.flag_outlined,
                label: 'Fin estimado',
                value: _shortDate(insights.estimatedEndDate),
              ),
            ],
          ),
          if (insights.trainingWeekdays.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Días de entrenamiento',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in const [
                  (DateTime.monday, 'L'),
                  (DateTime.tuesday, 'M'),
                  (DateTime.wednesday, 'X'),
                  (DateTime.thursday, 'J'),
                  (DateTime.friday, 'V'),
                  (DateTime.saturday, 'S'),
                  (DateTime.sunday, 'D'),
                ])
                  _DayBadge(
                    label: entry.$2,
                    active: insights.trainingWeekdays.contains(entry.$1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 138, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 15,
      backgroundColor:
          active ? colors.primary : colors.surfaceContainerHighest,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyPrograms extends StatelessWidget {
  const _EmptyPrograms({required this.hasRoutines});

  final bool hasRoutines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined, size: 56),
            const SizedBox(height: 14),
            Text(
              'Todavía no tienes un plan de entrenamiento',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasRoutines
                  ? 'Crea una rotación usando tus rutinas existentes y elige los días en que entrenas.'
                  : 'Primero crea una rutina y luego podrás organizarla dentro de un plan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
