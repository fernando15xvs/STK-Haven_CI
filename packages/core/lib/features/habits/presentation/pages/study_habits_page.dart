import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/coach/application/coach_task_provider.dart';
import 'package:core/domain/models/study_plan.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/study_plan_catalog.dart';
import 'package:core/features/habits/application/study_plan_provider.dart';
import 'package:core/features/habits/presentation/pages/habit_study_timer_page.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyHabitsPage extends ConsumerWidget {
  const StudyHabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(coachTaskLazySyncProvider);
    final visibleTasks = ref.watch(visibleHabitTasksProvider);
    final state = ref.watch(habitTasksProvider);
    final dueToday = ref.watch(dueHabitTasksTodayProvider);
    final activeTimer = ref.watch(habitStudyTimerProvider);
    final studyPlans = ref.watch(studyPlanEnrollmentsProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );
    final now = DateTime.now();

    final hasBibleTemplate = visibleTasks.any(
      (task) =>
          task.faithSpecific &&
          task.type == HabitTaskType.readingTimer &&
          task.targetMinutes == 10,
    );
    final latestCompletions =
        state.completions.take(10).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study & Hábitos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTaskDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva tarea'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              children: [
                _OverviewCard(
                  pendingToday: dueToday.length,
                  completedToday: state.completions
                      .where(
                        (completion) =>
                            completion.status ==
                                HabitTaskCompletionStatus.completed &&
                            completion.completedAt.year == now.year &&
                            completion.completedAt.month == now.month &&
                            completion.completedAt.day == now.day,
                      )
                      .length,
                ),
                if (activeTimer != null) ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final task = visibleTasks
                          .where((item) => item.id == activeTimer.taskId)
                          .firstOrNull;
                      if (task == null) return const SizedBox.shrink();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.timer_outlined),
                          title: Text('Sesión activa · ${task.title}'),
                          subtitle: Text(
                            activeTimer.isRunning
                                ? 'El temporizador está en curso'
                                : 'El temporizador está pausado',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openTimer(context, task),
                        ),
                      );
                    },
                  ),
                ],
                if (faithEnabled && !hasBibleTemplate) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leer la Biblia · 10 min',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Crea una tarea diaria de lectura con temporizador y espacio para una reflexión.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(habitTasksProvider.notifier)
                                  .createFromTemplate(
                                    HabitTaskTemplates
                                        .bibleReading10Minutes,
                                  );
                            },
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Añadir a mis hábitos'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (faithEnabled) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'Planes de estudio',
                    subtitle:
                        'Avanza por referencias; el texto bíblico sigue separado del plan.',
                  ),
                  const SizedBox(height: 10),
                  if (studyPlans.isEmpty)
                    const _EmptyCard(
                      icon: Icons.auto_stories_outlined,
                      text: 'Todavía no has iniciado un plan de estudio.',
                    )
                  else
                    for (final enrollment in studyPlans) ...[
                      Builder(
                        builder: (context) {
                          final plan =
                              StudyPlanCatalog.byId(enrollment.planId);
                          if (plan == null) {
                            return const SizedBox.shrink();
                          }
                          return _StudyPlanEnrollmentCard(
                            enrollment: enrollment,
                            plan: plan,
                            onTogglePause: () => ref
                                .read(studyPlanEnrollmentsProvider.notifier)
                                .setPaused(
                                  enrollment.id,
                                  !enrollment.paused,
                                ),
                            onCompleteStep: () async {
                              final next = enrollment.nextStepIndex(
                                plan.steps.length,
                              );
                              if (next == null) return;
                              await ref
                                  .read(
                                    studyPlanEnrollmentsProvider.notifier,
                                  )
                                  .completeStep(enrollment.id, next);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  OutlinedButton.icon(
                    onPressed: () => _showStudyPlanPicker(context, ref),
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Explorar planes'),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Para hoy',
                  subtitle: dueToday.isEmpty
                      ? 'No tienes tareas pendientes para hoy.'
                      : '${dueToday.length} pendiente(s)',
                ),
                const SizedBox(height: 10),
                if (dueToday.isEmpty)
                  const _EmptyCard(
                    icon: Icons.check_circle_outline,
                    text: 'Todo al día.',
                  )
                else
                  for (final task in dueToday) ...[
                    _HabitTaskCard(
                      task: task,
                      streak: HabitScheduleService.currentStreak(
                        task: task,
                        completions: state.completions,
                        today: now,
                      ),
                      onOpen: () => _handleTask(context, ref, task),
                      onComplete: () => _handleTask(context, ref, task),
                      onArchive: task.source == HabitTaskSource.coach
                          ? null
                          : () => ref
                              .read(habitTasksProvider.notifier)
                              .archiveTask(task.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: 'Mis hábitos y tareas',
                  subtitle: 'Tus tareas activas, propias o asignadas.',
                ),
                const SizedBox(height: 10),
                if (visibleTasks.isEmpty)
                  const _EmptyCard(
                    icon: Icons.task_alt_outlined,
                    text: 'Todavía no has creado tareas.',
                  )
                else
                  for (final task in visibleTasks) ...[
                    _HabitTaskCard(
                      task: task,
                      streak: HabitScheduleService.currentStreak(
                        task: task,
                        completions: state.completions,
                        today: now,
                      ),
                      onOpen: () => _handleTask(context, ref, task),
                      onComplete: () => _handleTask(context, ref, task),
                      onArchive: task.source == HabitTaskSource.coach
                          ? null
                          : () => ref
                              .read(habitTasksProvider.notifier)
                              .archiveTask(task.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: 'Historial reciente',
                  subtitle: 'Progreso, no perfección.',
                ),
                const SizedBox(height: 10),
                if (latestCompletions.isEmpty)
                  const _EmptyCard(
                    icon: Icons.history_rounded,
                    text: 'Aún no hay sesiones completadas.',
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < latestCompletions.length; i++) ...[
                          _CompletionTile(
                            completion: latestCompletions[i],
                            task: visibleTasks
                                .where(
                                  (task) =>
                                      task.id ==
                                      latestCompletions[i].taskId,
                                )
                                .firstOrNull,
                          ),
                          if (i != latestCompletions.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _handleTask(
    BuildContext context,
    WidgetRef ref,
    HabitTask task,
  ) async {
    if (task.source == HabitTaskSource.coach) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta tarea fue asignada por tu entrenador. '
            'Complétala desde Coach & Clientes > Tareas asignadas.',
          ),
        ),
      );
      return;
    }

    if (task.type == HabitTaskType.readingTimer ||
        task.type == HabitTaskType.studySession) {
      await _openTimer(context, task);
      return;
    }

    await ref.read(habitTasksProvider.notifier).completeTask(
          taskId: task.id,
        );
  }

  static Future<void> _openTimer(
    BuildContext context,
    HabitTask task,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HabitStudyTimerPage(task: task),
      ),
    );
  }

  static Future<void> _showStudyPlanPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Planes de estudio'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: StudyPlanCatalog.plans.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final plan = StudyPlanCatalog.plans[index];
              return ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(plan.title),
                subtitle: Text(plan.description),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () async {
                  await ref
                      .read(studyPlanEnrollmentsProvider.notifier)
                      .enroll(plan.id);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showCreateTaskDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final minutesController = TextEditingController(text: '10');
    var type = HabitTaskType.checklist;
    var recurrence = HabitRecurrenceType.once;
    var weekdays = <int>{};
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nueva tarea'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<HabitTaskType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                      ),
                      items: HabitTaskType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_typeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutos objetivo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<HabitRecurrenceType>(
                      initialValue: recurrence,
                      decoration: const InputDecoration(
                        labelText: 'Recurrencia',
                      ),
                      items: HabitRecurrenceType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_recurrenceLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => recurrence = value);
                      },
                    ),
                    if (recurrence == HabitRecurrenceType.weekly) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                          return FilterChip(
                            label: Text(entry.$2),
                            selected: weekdays.contains(day),
                            onSelected: (selected) {
                              setDialogState(() {
                                final next = Set<int>.from(weekdays);
                                if (selected) {
                                  next.add(day);
                                } else {
                                  next.remove(day);
                                }
                                weekdays = next;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        setDialogState(() => saving = true);
                        try {
                          await ref
                              .read(habitTasksProvider.notifier)
                              .createTask(
                                title: title,
                                category: categoryController.text,
                                type: type,
                                targetMinutes:
                                    int.tryParse(minutesController.text) ??
                                        0,
                                recurrence: recurrence,
                                weekdays: weekdays,
                              );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Guardando…' : 'Crear'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    categoryController.dispose();
    minutesController.dispose();
  }

  static String _typeLabel(HabitTaskType value) => switch (value) {
        HabitTaskType.checklist => 'Checklist',
        HabitTaskType.readingTimer => 'Lectura con temporizador',
        HabitTaskType.studySession => 'Sesión de estudio',
        HabitTaskType.reflection => 'Reflexión',
        HabitTaskType.custom => 'Personalizada',
      };

  static String _recurrenceLabel(HabitRecurrenceType value) => switch (value) {
        HabitRecurrenceType.once => 'Una vez',
        HabitRecurrenceType.daily => 'Diaria',
        HabitRecurrenceType.weekly => 'Semanal',
      };
}

class _StudyPlanEnrollmentCard extends StatelessWidget {
  final StudyPlanEnrollment enrollment;
  final StudyPlanDefinition plan;
  final VoidCallback onTogglePause;
  final VoidCallback onCompleteStep;

  const _StudyPlanEnrollmentCard({
    required this.enrollment,
    required this.plan,
    required this.onTogglePause,
    required this.onCompleteStep,
  });

  @override
  Widget build(BuildContext context) {
    final nextIndex = enrollment.nextStepIndex(plan.steps.length);
    final complete = nextIndex == null;
    final nextStep = complete ? null : plan.steps[nextIndex];
    final progress = plan.steps.isEmpty
        ? 0.0
        : (enrollment.completedStepIndices.length / plan.steps.length)
            .clamp(0.0, 1.0)
            .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (enrollment.paused)
                  const Chip(label: Text('Pausado')),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 8),
            Text(
              '${enrollment.completedStepIndices.length}/${plan.steps.length} sesiones',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (nextStep != null) ...[
              const SizedBox(height: 12),
              Text(
                'Siguiente: ${nextStep.title}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(nextStep.reference),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Plan completado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!complete)
                  FilledButton.icon(
                    onPressed: enrollment.paused ? null : onCompleteStep,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Completar sesión'),
                  ),
                if (!complete)
                  TextButton.icon(
                    onPressed: onTogglePause,
                    icon: Icon(
                      enrollment.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(
                      enrollment.paused ? 'Reanudar' : 'Pausar',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final int pendingToday;
  final int completedToday;

  const _OverviewCard({
    required this.pendingToday,
    required this.completedToday,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Pendientes hoy',
                value: '$pendingToday',
                icon: Icons.pending_actions_outlined,
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'Completadas hoy',
                value: '$completedToday',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HabitTaskCard extends StatelessWidget {
  final HabitTask task;
  final int streak;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final VoidCallback? onArchive;

  const _HabitTaskCard({
    required this.task,
    required this.streak,
    required this.onOpen,
    required this.onComplete,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final timed = task.type == HabitTaskType.readingTimer ||
        task.type == HabitTaskType.studySession;

    return Card(
      child: ListTile(
        leading: Icon(
          timed ? Icons.timer_outlined : Icons.task_alt_outlined,
        ),
        title: Text(task.title),
        subtitle: Text(
          [
            task.category,
            if (task.source == HabitTaskSource.coach)
              'Asignada por entrenador',
            if (task.targetMinutes > 0) '${task.targetMinutes} min',
            if (streak > 0) 'Racha actual: $streak',
          ].join(' · '),
        ),
        onTap: onOpen,
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: timed ? 'Abrir sesión' : 'Completar',
              onPressed: timed ? onOpen : onComplete,
              icon: Icon(
                timed
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
              ),
            ),
            if (onArchive != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'archive') onArchive?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('Archivar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  final HabitTaskCompletion completion;
  final HabitTask? task;

  const _CompletionTile({
    required this.completion,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final date = completion.completedAt;
    final day =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final skipped =
        completion.status == HabitTaskCompletionStatus.skipped;
    return ListTile(
      leading: Icon(
        skipped ? Icons.remove_circle_outline : Icons.check_circle_outline,
      ),
      title: Text(
        task?.title ??
            (skipped ? 'Tarea omitida' : 'Tarea completada'),
      ),
      subtitle: Text(
        [
          day,
          skipped ? 'Omitida' : 'Completada',
          if (completion.minutesSpent > 0)
            '${completion.minutesSpent} min',
          if (completion.note.isNotEmpty) completion.note,
        ].join(' · '),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
