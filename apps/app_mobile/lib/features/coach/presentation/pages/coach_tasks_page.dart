import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/coach/application/coach_task_notification_service.dart';
import 'package:core/features/coach/application/coach_task_provider.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachTasksPage extends ConsumerStatefulWidget {
  final String clientUserId;
  final String clientDisplayName;
  final bool canAssign;
  final bool canComment;

  const CoachTasksPage({
    super.key,
    required this.clientUserId,
    required this.clientDisplayName,
    required this.canAssign,
    required this.canComment,
  });

  @override
  ConsumerState<CoachTasksPage> createState() => _CoachTasksPageState();
}

class _CoachTasksPageState extends ConsumerState<CoachTasksPage> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await ref
        .read(coachTaskProvider.notifier)
        .refresh(clientUserId: widget.clientUserId);
    if (!mounted) return;
    await ref
        .read(coachTaskProvider.notifier)
        .loadAdherence(widget.clientUserId);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(appIdentityProvider);
    final state = ref.watch(coachTaskProvider);
    final userId = identity.userId;
    final tasks = state.tasks
        .where((task) => task.clientUserId == widget.clientUserId)
        .toList(growable: false);
    final asCoach = tasks.isNotEmpty
        ? tasks.first.isCoach(userId)
        : userId != widget.clientUserId;
    final adherence = state.adherenceByClient[widget.clientUserId];

    ref.listen(coachTaskProvider, (previous, next) {
      if (next.message == null || next.message == previous?.message) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.message!)),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Tareas · ${widget.clientDisplayName}'),
      ),
      floatingActionButton: asCoach && widget.canAssign
          ? FloatingActionButton.extended(
              onPressed: state.busy ? null : _showAssignDialog,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Asignar tarea'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  _AdherenceCard(
                    adherence: adherence,
                    loading: state.operation == CoachTaskOperation.loading,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        asCoach
                            ? 'Las tareas colaborativas usan un permiso separado. '
                                'El cliente conserva su historial aunque la relación '
                                'se revoque.'
                            : 'Las tareas asignadas también aparecen en Study & '
                                'Hábitos como tareas de origen Entrenador. '
                                'Los recordatorios son opcionales y se activan '
                                'solo en este dispositivo.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!identity.signedIn)
                    const _EmptyState(
                      text:
                          'Se necesita una cuenta permanente para usar tareas compartidas.',
                    )
                  else if (state.operation == CoachTaskOperation.loading &&
                      tasks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (tasks.isEmpty)
                    const _EmptyState(
                      text: 'Todavía no hay tareas asignadas.',
                    )
                  else
                    for (final task in tasks) ...[
                      _TaskCard(
                        task: task,
                        currentUserId: userId,
                        occurrences:
                            ref.read(coachTaskProvider.notifier).occurrencesFor(
                                  task.id,
                                ),
                        canComment: widget.canComment || task.isClient(userId),
                        busy: state.busy,
                        onComplete: () => _resolve(
                          task,
                          CoachTaskOccurrenceStatus.completed,
                        ),
                        onSkip: () => _resolve(
                          task,
                          CoachTaskOccurrenceStatus.skipped,
                        ),
                        onComments: () => _showComments(task),
                        onArchive: task.isCoach(userId) && widget.canAssign
                            ? () => ref
                                .read(coachTaskProvider.notifier)
                                .archiveTask(task)
                            : null,
                        onToggleReminder: task.isClient(userId)
                            ? (enabled) => _toggleReminder(task, enabled)
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolve(
    CoachAssignedTask task,
    CoachTaskOccurrenceStatus status,
  ) async {
    final today = DateTime.now();
    final localTask = task.toLocalHabitTask();
    if (!HabitScheduleService.isDueOn(localTask, today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta tarea no corresponde a hoy.')),
      );
      return;
    }

    int minutes = 0;
    if (status == CoachTaskOccurrenceStatus.completed &&
        task.targetMinutes > 0) {
      final controller = TextEditingController(
        text: task.targetMinutes.toString(),
      );
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Completar tarea'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutos realizados',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                int.tryParse(controller.text) ?? 0,
              ),
              child: const Text('Completar'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (result == null) return;
      minutes = result.clamp(0, 1440).toInt();
    } else if (status == CoachTaskOccurrenceStatus.skipped) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Omitir tarea'),
          content: const Text(
            'La tarea quedará registrada como omitida para hoy. '
            'Este resultado no se reescribe después.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Omitir'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final success = await ref.read(coachTaskProvider.notifier).resolveOccurrence(
          task: task,
          occurrenceDate: today,
          status: status,
          minutesSpent: minutes,
        );

    if (success && task.isClient(ref.read(appIdentityProvider).userId)) {
      final local = ref
          .read(habitTaskRepositoryProvider)
          .getTask('coach::${task.id}');
      if (local?.reminderEnabled == true) {
        await CoachTaskNotificationService.cancelReminder(local!.id);
        await CoachTaskNotificationService.scheduleNextReminder(
          local,
          from: today.add(const Duration(days: 1)),
          requestPermissionIfNeeded: false,
        );
      }
    }
  }

  Future<void> _toggleReminder(
    CoachAssignedTask task,
    bool enabled,
  ) async {
    final repository = ref.read(habitTaskRepositoryProvider);
    final id = 'coach::${task.id}';
    final current = repository.getTask(id) ?? task.toLocalHabitTask();
    final next = current.copyWith(reminderEnabled: enabled);
    await repository.saveTask(next);
    ref.read(habitTasksProvider.notifier).refresh();

    if (!enabled) {
      await CoachTaskNotificationService.cancelReminder(next.id);
      if (mounted) setState(() {});
      return;
    }

    final scheduled =
        await CoachTaskNotificationService.scheduleNextReminder(next);
    if (!scheduled) {
      await repository.saveTask(next.copyWith(reminderEnabled: false));
      ref.read(habitTasksProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo activar el recordatorio. Revisa los permisos de notificaciones.',
            ),
          ),
        );
        setState(() {});
      }
      return;
    }

    if (mounted) setState(() {});
  }

  Future<void> _showAssignDialog() async {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final minutesController = TextEditingController(text: '0');
    final instructionsController = TextEditingController();

    var type = HabitTaskType.checklist;
    var recurrence = HabitRecurrenceType.once;
    var weekdays = <int>{};
    var startsOn = DateTime.now();
    DateTime? dueAt;
    DateTime? endsOn;

    final payload = await showDialog<_TaskDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Asignar tarea'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HabitTaskType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      for (final value in HabitTaskType.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_taskTypeLabel(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Minutos objetivo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HabitRecurrenceType>(
                    initialValue: recurrence,
                    decoration:
                        const InputDecoration(labelText: 'Recurrencia'),
                    items: [
                      for (final value in HabitRecurrenceType.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_recurrenceLabel(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        recurrence = value;
                        if (value != HabitRecurrenceType.weekly) {
                          weekdays = <int>{};
                        }
                      });
                    },
                  ),
                  if (recurrence == HabitRecurrenceType.weekly) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                          FilterChip(
                            label: Text(entry.$2),
                            selected: weekdays.contains(entry.$1),
                            onSelected: (selected) {
                              setDialogState(() {
                                final next = Set<int>.from(weekdays);
                                if (selected) {
                                  next.add(entry.$1);
                                } else {
                                  next.remove(entry.$1);
                                }
                                weekdays = next;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Inicio',
                    value: startsOn,
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)),
                        initialDate: startsOn,
                      );
                      if (selected != null) {
                        setDialogState(() => startsOn = selected);
                      }
                    },
                  ),
                  if (recurrence == HabitRecurrenceType.once)
                    _DateRow(
                      label: 'Fecha límite',
                      value: dueAt,
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: startsOn,
                          lastDate:
                              startsOn.add(const Duration(days: 730)),
                          initialDate: dueAt ?? startsOn,
                        );
                        if (selected != null) {
                          setDialogState(() {
                            dueAt = DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                              18,
                            );
                          });
                        }
                      },
                    ),
                  if (recurrence != HabitRecurrenceType.once)
                    _DateRow(
                      label: 'Fin opcional',
                      value: endsOn,
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: startsOn,
                          lastDate:
                              startsOn.add(const Duration(days: 730)),
                          initialDate: endsOn ?? startsOn,
                        );
                        if (selected != null) {
                          setDialogState(() => endsOn = selected);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones / comentario inicial',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                if (recurrence == HabitRecurrenceType.weekly &&
                    weekdays.isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _TaskDraft(
                    title: title,
                    category: categoryController.text,
                    type: type,
                    targetMinutes:
                        int.tryParse(minutesController.text) ?? 0,
                    recurrence: recurrence,
                    weekdays: weekdays,
                    startsOn: startsOn,
                    dueAt: dueAt,
                    endsOn: endsOn,
                    instructions: instructionsController.text,
                  ),
                );
              },
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    categoryController.dispose();
    minutesController.dispose();
    instructionsController.dispose();

    if (payload == null || !mounted) return;
    await ref.read(coachTaskProvider.notifier).assignTask(
          clientUserId: widget.clientUserId,
          title: payload.title,
          category: payload.category,
          type: payload.type,
          targetMinutes: payload.targetMinutes,
          recurrence: payload.recurrence,
          weekdays: payload.weekdays,
          startsOn: payload.startsOn,
          dueAt: payload.dueAt,
          endsOn: payload.endsOn,
          instructions: payload.instructions,
        );
    if (mounted) {
      await ref
          .read(coachTaskProvider.notifier)
          .loadAdherence(widget.clientUserId);
    }
  }

  Future<void> _showComments(CoachAssignedTask task) async {
    await ref.read(coachTaskProvider.notifier).loadComments(task.id);
    if (!mounted) return;

    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final comments =
              ref.watch(coachTaskProvider).commentsByTask[task.id] ??
                  const <CoachTaskComment>[];
          final userId = ref.watch(appIdentityProvider).userId;
          return AlertDialog(
            title: Text('Comentarios · ${task.title}'),
            content: SizedBox(
              width: 560,
              height: 420,
              child: Column(
                children: [
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text('Todavía no hay comentarios.'),
                          )
                        : ListView.separated(
                            itemCount: comments.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final mine = comment.authorUserId == userId;
                              return ListTile(
                                leading: Icon(
                                  mine
                                      ? Icons.person_outline
                                      : Icons.chat_bubble_outline,
                                ),
                                title: Text(
                                  mine ? 'Tú' : 'Otra persona vinculada',
                                ),
                                subtitle: Text(comment.body),
                              );
                            },
                          ),
                  ),
                  if (widget.canComment || task.isClient(userId)) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Añadir comentario',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
              if (widget.canComment ||
                  task.isClient(ref.read(appIdentityProvider).userId))
                FilledButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    final ok = await ref
                        .read(coachTaskProvider.notifier)
                        .addComment(
                          taskId: task.id,
                          body: controller.text,
                        );
                    if (ok) controller.clear();
                  },
                  child: const Text('Enviar'),
                ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }
}

class _TaskCard extends ConsumerWidget {
  final CoachAssignedTask task;
  final String? currentUserId;
  final List<CoachTaskOccurrence> occurrences;
  final bool canComment;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onComments;
  final VoidCallback? onArchive;
  final ValueChanged<bool>? onToggleReminder;

  const _TaskCard({
    required this.task,
    required this.currentUserId,
    required this.occurrences,
    required this.canComment,
    required this.busy,
    required this.onComplete,
    required this.onSkip,
    required this.onComments,
    required this.onArchive,
    required this.onToggleReminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final localTask = task.toLocalHabitTask();
    final dueToday = HabitScheduleService.isDueOn(localTask, today);
    CoachTaskOccurrence? todayOccurrence;
    for (final occurrence in occurrences) {
      if (_sameDay(occurrence.occurrenceDate, today)) {
        todayOccurrence = occurrence;
        break;
      }
    }

    final localMirror = ref
        .watch(habitTasksProvider)
        .tasks
        .where((item) => item.sourceReference == task.id)
        .firstOrNull;
    final reminderEnabled = localMirror?.reminderEnabled ?? false;
    final isClient = task.isClient(currentUserId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.type == HabitTaskType.readingTimer ||
                          task.type == HabitTaskType.studySession
                      ? Icons.timer_outlined
                      : Icons.task_alt_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                  label: Text(
                    task.status == CoachAssignedTaskStatus.active
                        ? 'Activa'
                        : 'Archivada',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                task.category,
                _recurrenceLabel(task.recurrence),
                if (task.targetMinutes > 0)
                  '${task.targetMinutes} min',
                if (dueToday && todayOccurrence == null) 'Pendiente hoy',
                if (todayOccurrence != null)
                  todayOccurrence.status ==
                          CoachTaskOccurrenceStatus.completed
                      ? 'Completada hoy'
                      : 'Omitida hoy',
              ].join(' · '),
            ),
            if (task.coachInstructions.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(task.coachInstructions),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isClient &&
                    task.isActive &&
                    dueToday &&
                    todayOccurrence == null) ...[
                  FilledButton.icon(
                    onPressed: busy ? null : onComplete,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Completar'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onSkip,
                    child: const Text('Omitir'),
                  ),
                ],
                if (canComment)
                  TextButton.icon(
                    onPressed: busy ? null : onComments,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Comentarios'),
                  ),
                if (onArchive != null && task.isActive)
                  TextButton.icon(
                    onPressed: busy ? null : onArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archivar'),
                  ),
              ],
            ),
            if (!kIsWeb &&
                isClient &&
                onToggleReminder != null &&
                task.isActive)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: reminderEnabled,
                onChanged: busy ? null : onToggleReminder,
                title: const Text('Recordarme'),
                subtitle: const Text(
                  'Solo en este dispositivo; tu entrenador no activa este permiso.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final CoachTaskAdherence? adherence;
  final bool loading;

  const _AdherenceCard({
    required this.adherence,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (adherence == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ],
              const Expanded(
                child: Text('Adherencia de tareas: todavía sin datos.'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adherencia · últimos ${adherence!.days} días',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (adherence!.adherencePercent / 100)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 10),
            Text(
              '${adherence!.adherencePercent.toStringAsFixed(1)}% · '
              '${adherence!.completedCount} completadas · '
              '${adherence!.skippedCount} omitidas · '
              '${adherence!.pendingCount} pendientes',
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(value == null ? 'Sin fecha' : _dateLabel(value!)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.task_alt_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  final String title;
  final String category;
  final HabitTaskType type;
  final int targetMinutes;
  final HabitRecurrenceType recurrence;
  final Set<int> weekdays;
  final DateTime startsOn;
  final DateTime? dueAt;
  final DateTime? endsOn;
  final String instructions;

  const _TaskDraft({
    required this.title,
    required this.category,
    required this.type,
    required this.targetMinutes,
    required this.recurrence,
    required this.weekdays,
    required this.startsOn,
    required this.dueAt,
    required this.endsOn,
    required this.instructions,
  });
}

String _taskTypeLabel(HabitTaskType value) => switch (value) {
      HabitTaskType.checklist => 'Checklist',
      HabitTaskType.readingTimer => 'Lectura con temporizador',
      HabitTaskType.studySession => 'Sesión de estudio',
      HabitTaskType.reflection => 'Reflexión',
      HabitTaskType.custom => 'Personalizada',
    };

String _recurrenceLabel(HabitRecurrenceType value) => switch (value) {
      HabitRecurrenceType.once => 'Una vez',
      HabitRecurrenceType.daily => 'Diaria',
      HabitRecurrenceType.weekly => 'Semanal',
    };

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

bool _sameDay(DateTime a, DateTime b) {
  final aa = a.toLocal();
  final bb = b.toLocal();
  return aa.year == bb.year &&
      aa.month == bb.month &&
      aa.day == bb.day;
}

extension _FirstOrNullCoachTask<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
