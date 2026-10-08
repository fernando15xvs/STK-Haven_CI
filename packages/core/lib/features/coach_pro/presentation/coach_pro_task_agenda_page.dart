import 'package:core/features/coach_pro/application/coach_pro_task_agenda_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_agenda.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_task_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coach-only operational preview; no background or automatic task actions.
class CoachProTaskAgendaPage extends ConsumerWidget {
  final String relationshipId;
  const CoachProTaskAgendaPage({super.key, required this.relationshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda de tareas')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Agenda(
            key: ValueKey(identity.userId),
            userId: identity.userId!,
            relationshipId: relationshipId,
          ),
    );
  }
}

class _Agenda extends ConsumerStatefulWidget {
  final String userId;
  final String relationshipId;
  const _Agenda({
    super.key,
    required this.userId,
    required this.relationshipId,
  });

  @override
  ConsumerState<_Agenda> createState() => _AgendaState();
}

class _AgendaState extends ConsumerState<_Agenda>
    with WidgetsBindingObserver {
  int _offset = 0;

  CoachProTaskAgendaQuery get _query => (
    userId: widget.userId,
    relationshipId: widget.relationshipId,
    offset: _offset,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  void _refresh() => ref.invalidate(coachProTaskAgendaPageProvider(_query));

  Future<void> _openTask(String taskId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachProTaskDetailPage(
          relationshipId: widget.relationshipId,
          taskId: taskId,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  String _status(CoachProAgendaStatus status) => switch (status) {
    CoachProAgendaStatus.unrecorded => 'Sin registro (no implica incumplimiento)',
    CoachProAgendaStatus.completed => 'Completada por el cliente',
    CoachProAgendaStatus.skipped => 'Omitida por el cliente',
  };

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProTaskAgendaPageProvider(_query));
    String date(DateTime d) =>
      MaterialLocalizations.of(context).formatMediumDate(d);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text('Próximos 14 días',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Las fechas se calculan desde las tareas asignadas. '
                  'Un día sin registro no indica que el cliente haya incumplido. '
                  'Las finalizaciones y omisiones solo aparecen si el cliente '
                  'las registró expresamente.'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: result.isLoading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ),
                result.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Column(children: [
                    const Text('No se pudo cargar la agenda. Revisa tu plan, '
                      'la conexión y los permisos de tareas del cliente.'),
                    TextButton(onPressed: _refresh,
                      child: const Text('Reintentar')),
                  ]),
                  data: (page) {
                    if (page == null) return const Text('Agenda no disponible.');
                    if (page.items.isEmpty && _offset == 0) {
                      return const Text('No hay tareas programadas para los '
                        'próximos catorce días.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in page.items)
                          Card(child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                  style: Theme.of(context).textTheme.titleMedium),
                                Text(date(item.dueOn)),
                                Text(_status(item.status)),
                                if (item.status == CoachProAgendaStatus.completed)
                                  Text('Tiempo registrado: ' +
                                    (item.minutesSpent ?? 0).toString() + ' min'),
                                TextButton(
                                  onPressed: () => _openTask(item.taskId),
                                  child: const Text('Abrir tarea'),
                                ),
                              ],
                            ),
                          )),
                        Text('Programaciones: ' + page.totalCount.toString()),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(
                            onPressed: _offset == 0 ? null
                              : () => setState(() => _offset -= 25),
                            child: const Text('Anterior')),
                          OutlinedButton(
                            onPressed: page.items.isNotEmpty &&
                                _offset + 25 < page.totalCount &&
                                _offset + 25 <= 10000
                              ? () => setState(() => _offset += 25)
                              : null,
                            child: const Text('Siguiente')),
                        ]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
