import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_volume_planner.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrainingProgramsPage extends ConsumerWidget {
  const TrainingProgramsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text('Programas 3.0'),
        actions: [
          IconButton(
            tooltip: 'Reconciliar con historial',
            onPressed: () => ref
                .read(trainingProgramListProvider.notifier)
                .reconcileActive(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: routines.isEmpty
            ? null
            : () => _showEditor(context, ref, routines, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo programa'),
      ),
      body: programs.isEmpty
          ? _EmptyPrograms(hasRoutines: routines.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                final volumes = ProgramVolumePlanner.calculateWeek(
                  program: program,
                  routines: routines,
                  history: history,
                  muscleGroupByExerciseId: muscleByExercise,
                  weekStart: _startOfWeek(DateTime.now()),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProgramCard(
                    program: program,
                    routineById: routineById,
                    volumes: volumes,
                    onActivate: () => ref
                        .read(trainingProgramListProvider.notifier)
                        .activate(program.id),
                    onEdit: () =>
                        _showEditor(context, ref, routines, program),
                    onDuplicate: () => ref
                        .read(trainingProgramListProvider.notifier)
                        .duplicate(program.id),
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
    final name = TextEditingController(text: existing?.name ?? 'Mi programa');
    final notes = TextEditingController(text: existing?.notes ?? '');
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
            title: Text(existing == null ? 'Crear programa' : 'Editar programa'),
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
        title: const Text('Eliminar programa'),
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
    required this.onActivate,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final TrainingProgram program;
  final Map<String, Routine> routineById;
  final List<ProgramMuscleVolume> volumes;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
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
                        program.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${program.routineIds.length} rutinas · Semana $week/${program.durationWeeks} · ${program.completions.length} completadas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'activate') return onActivate();
                    if (value == 'edit') return onEdit();
                    if (value == 'duplicate') return onDuplicate();
                    if (value == 'delete') return onDelete();
                  },
                  itemBuilder: (context) => [
                    if (!program.isActive)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Text('Activar'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar programa'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.skip_next_rounded),
              title: const Text('Siguiente sesión'),
              subtitle: Text(nextRoutine?.name ?? 'Rutina no disponible'),
              trailing: program.isDeloadWeekAt(now)
                  ? const Chip(label: Text('Descarga'))
                  : null,
            ),
            if (program.notes.isNotEmpty) Text(program.notes),
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
            if (volumes.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Volumen semanal previsto vs realizado'),
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

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
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
              'Todavía no tienes Programas 2.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasRoutines
                  ? 'Crea una rotación A/B/C usando tus rutinas existentes.'
                  : 'Primero crea una rutina y luego podrás agruparla en un programa.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
