import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/coach_pro/application/coach_pro_task_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProTaskDetailPage extends ConsumerWidget {
  final String relationshipId, taskId;
  const CoachProTaskDetailPage({super.key, required this.relationshipId, required this.taskId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(appBar: AppBar(title: const Text('Tarea asignada')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Task(key: ValueKey(identity.userId), relationshipId: relationshipId, taskId: taskId));
  }
}
class _Task extends ConsumerStatefulWidget {
  final String relationshipId, taskId;
  const _Task({super.key, required this.relationshipId, required this.taskId});
  @override
  ConsumerState<_Task> createState() => _TaskState();
}
class _TaskState extends ConsumerState<_Task> with WidgetsBindingObserver {
  int _offset = 0;
  CoachProTaskQuery get _query =>
      (relationshipId: widget.relationshipId, taskId: widget.taskId, offset: _offset);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }
  void _refresh() => ref.invalidate(coachProTaskPageProvider(_query));
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProTaskPageProvider(_query));
    String date(DateTime value) => MaterialLocalizations.of(context).formatMediumDate(value);
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: result.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
        result.when(skipLoadingOnRefresh: false, skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo consultar la tarea. Comprueba la conexión y los permisos vigentes.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Tarea no disponible.');
            final task = page.task;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
              Text('${task.category} · ${task.isActive ? 'Activa' : 'Archivada'}'),
              Text('${_type(task.type)} · ${_recurrence(task.recurrence)}'),
              if (task.recurrence == HabitRecurrenceType.weekly)
                Text('Días: ${(task.weekdays.toList()..sort()).map((d) => _days[d - 1]).join(', ')}'),
              Text('Objetivo: ${task.targetMinutes} min'),
              Text('Inicio: ${date(task.startsOn)}'),
              if (task.endsOn != null) Text('Fin: ${date(task.endsOn!)}'),
              if (task.dueAt != null) Text('Vencimiento: ${date(task.dueAt!.toLocal())}'),
              if (task.coachInstructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Indicaciones del entrenador'),
                Text(task.coachInstructions),
              ],
              const SizedBox(height: 20),
              Text('Historial registrado', style: Theme.of(context).textTheme.titleLarge),
              const Text('Solo se muestran registros existentes; los días sin registro no se consideran incumplidos.'),
              if (page.occurrences.isEmpty)
                Text(_offset == 0 ? 'Todavía no hay registros para esta tarea.'
                    : 'Esta página está vacía. Vuelve a la anterior.'),
              for (final item in page.occurrences)
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(date(item.occurrenceDate)),
                    Text(item.status == CoachTaskOccurrenceStatus.completed ? 'Completada' : 'Omitida'),
                    Text('${item.minutesSpent} min registrados'),
                  ]),
                )),
              const SizedBox(height: 12),
              Text('${page.totalCount} registros · Página ${_offset ~/ 25 + 1}'),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton(onPressed: _offset > 0 ? () => setState(() => _offset -= 25) : null,
                  child: const Text('Anterior')),
                OutlinedButton(onPressed: page.occurrences.isNotEmpty &&
                    _offset + 25 < page.totalCount && _offset + 25 <= 10000
                    ? () => setState(() => _offset += 25) : null, child: const Text('Siguiente')),
              ]),
            ]);
          }),
      ]),
    )));
  }
}
const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
String _type(HabitTaskType type) => switch (type) {
  HabitTaskType.checklist => 'Lista', HabitTaskType.readingTimer => 'Lectura',
  HabitTaskType.studySession => 'Estudio', HabitTaskType.reflection => 'Reflexión',
  HabitTaskType.custom => 'Personalizada',
};
String _recurrence(HabitRecurrenceType recurrence) => switch (recurrence) {
  HabitRecurrenceType.once => 'Una vez', HabitRecurrenceType.daily => 'Diaria',
  HabitRecurrenceType.weekly => 'Semanal',
};
