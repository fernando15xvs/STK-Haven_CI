import 'package:core/features/coach_pro/application/coach_pro_program_revision_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_program_revision_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_program_revision.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProProgramRevisionHistoryPage extends ConsumerWidget {
  final String relationshipId;
  final String assignmentId;
  final String assignmentName;

  const CoachProProgramRevisionHistoryPage({
    super.key,
    required this.relationshipId,
    required this.assignmentId,
    required this.assignmentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de revisiones')),
      body: !identity.signedIn || identity.userId == null
          ? const Center(
              child: Text('Inicia sesión con una cuenta permanente.'),
            )
          : _RevisionHistory(
              key: ValueKey(identity.userId),
              relationshipId: relationshipId,
              assignmentId: assignmentId,
              assignmentName: assignmentName,
            ),
    );
  }
}

class _RevisionHistory extends ConsumerStatefulWidget {
  final String relationshipId;
  final String assignmentId;
  final String assignmentName;

  const _RevisionHistory({
    super.key,
    required this.relationshipId,
    required this.assignmentId,
    required this.assignmentName,
  });

  @override
  ConsumerState<_RevisionHistory> createState() => _RevisionHistoryState();
}

class _RevisionHistoryState extends ConsumerState<_RevisionHistory>
    with WidgetsBindingObserver {
  int _offset = 0;

  CoachProProgramRevisionHistoryQuery get _query => (
        relationshipId: widget.relationshipId,
        assignmentId: widget.assignmentId,
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

  void _refresh() => ref.invalidate(
        coachProProgramRevisionHistoryProvider(_query),
      );

  Future<void> _openRevision(CoachProProgramRevisionSummary revision) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachProProgramRevisionDetailPage(
          relationshipId: widget.relationshipId,
          assignmentId: widget.assignmentId,
          revisionId: revision.id,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProProgramRevisionHistoryProvider(_query));
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.assignmentName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Las revisiones son propuestas inmutables. Consultar este '
                'historial no cambia el programa instalado del cliente.',
              ),
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
                error: (_, _) => Column(
                  children: [
                    const Text(
                      'No se pudo consultar el historial. Revisa la conexión, '
                      'el permiso para programas y tu acceso Coach Pro.',
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
                data: (page) {
                  if (page == null) {
                    return const Text('Historial no disponible.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Versión actual del programa: ${page.currentAssignmentVersion}',
                      ),
                      Text(
                        '${page.totalCount} revisiones registradas · '
                        'Página ${_offset ~/ CoachProProgramRevisionService.pageSize + 1}',
                      ),
                      const SizedBox(height: 12),
                      if (page.items.isEmpty)
                        Text(
                          _offset == 0
                              ? 'Todavía no hay revisiones registradas.'
                              : 'Esta página está vacía. Vuelve a la anterior.',
                        ),
                      for (final revision in page.items)
                        Card(
                          child: ListTile(
                            title: Text(
                              'Revisión ${revision.revisionNumber}',
                            ),
                            subtitle: Text(
                              '${revision.source.label} · '
                              '${_authorLabel(revision.source)}\n'
                              '${_date(context, revision.displayDate)} · '
                              'programa observado v${revision.observedAssignmentVersion}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRevision(revision),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _offset > 0
                                ? () => setState(
                                      () => _offset -=
                                          CoachProProgramRevisionService
                                              .pageSize,
                                    )
                                : null,
                            child: const Text('Anterior'),
                          ),
                          OutlinedButton(
                            onPressed: page.items.isNotEmpty &&
                                    _offset +
                                            CoachProProgramRevisionService
                                                .pageSize <
                                        page.totalCount &&
                                    _offset +
                                            CoachProProgramRevisionService
                                                .pageSize <=
                                        10000
                                ? () => setState(
                                      () => _offset +=
                                          CoachProProgramRevisionService
                                              .pageSize,
                                    )
                                : null,
                            child: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoachProProgramRevisionDetailPage extends ConsumerWidget {
  final String relationshipId;
  final String assignmentId;
  final String revisionId;
  final String? routineId;

  const CoachProProgramRevisionDetailPage({
    super.key,
    required this.relationshipId,
    required this.assignmentId,
    required this.revisionId,
    this.routineId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          routineId == null ? 'Detalle de revisión' : 'Rutina de la revisión',
        ),
      ),
      body: !identity.signedIn || identity.userId == null
          ? const Center(
              child: Text('Inicia sesión con una cuenta permanente.'),
            )
          : _RevisionDetail(
              key: ValueKey(identity.userId),
              relationshipId: relationshipId,
              assignmentId: assignmentId,
              revisionId: revisionId,
              routineId: routineId,
            ),
    );
  }
}

class _RevisionDetail extends ConsumerStatefulWidget {
  final String relationshipId;
  final String assignmentId;
  final String revisionId;
  final String? routineId;

  const _RevisionDetail({
    super.key,
    required this.relationshipId,
    required this.assignmentId,
    required this.revisionId,
    required this.routineId,
  });

  @override
  ConsumerState<_RevisionDetail> createState() => _RevisionDetailState();
}

class _RevisionDetailState extends ConsumerState<_RevisionDetail>
    with WidgetsBindingObserver {
  int _offset = 0;

  CoachProProgramRevisionDetailQuery get _query => (
        relationshipId: widget.relationshipId,
        assignmentId: widget.assignmentId,
        revisionId: widget.revisionId,
        routineId: widget.routineId,
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

  void _refresh() => ref.invalidate(
        coachProProgramRevisionDetailProvider(_query),
      );

  Future<void> _openRoutine(String routineId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachProProgramRevisionDetailPage(
          relationshipId: widget.relationshipId,
          assignmentId: widget.assignmentId,
          revisionId: widget.revisionId,
          routineId: routineId,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProProgramRevisionDetailProvider(_query));
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                error: (_, _) => Column(
                  children: [
                    const Text(
                      'No se pudo abrir esta revisión. Revisa la conexión y '
                      'que el acceso al programa siga vigente.',
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
                data: (page) {
                  if (page == null) {
                    return const Text('Revisión no disponible.');
                  }
                  final count = widget.routineId == null
                      ? page.routines.length
                      : page.exercises.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        page.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Revisión ${page.revisionNumber} · '
                        '${page.source.label}',
                      ),
                      Text(
                        'Autor: ${_authorLabel(page.source)} · '
                        '${_date(context, page.displayDate)}',
                      ),
                      Text(
                        'Programa observado: v${page.observedAssignmentVersion}',
                      ),
                      if (widget.routineId == null) ...[
                        Text('Duración: ${page.durationWeeks} semanas'),
                        Text(
                          'Días: ${_weekdays(page.trainingWeekdays)}',
                        ),
                        Text(
                          'Inicio: ${_date(context, page.startsOn)}',
                        ),
                        const SizedBox(height: 16),
                        _RevisionComparison(
                          current: page,
                          relationshipId: widget.relationshipId,
                          assignmentId: widget.assignmentId,
                        ),
                      ],
                      if (page.routineName != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          page.routineName!,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (count == 0)
                        Text(
                          _offset == 0
                              ? 'No hay elementos en esta sección.'
                              : 'Esta página está vacía. Vuelve a la anterior.',
                        ),
                      for (final routine in page.routines)
                        Card(
                          child: ListTile(
                            title: Text(routine.name),
                            subtitle:
                                Text('Rutina ${routine.position + 1}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRoutine(routine.id),
                          ),
                        ),
                      for (final exercise in page.exercises)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${exercise.targetSets} series · '
                                  '${exercise.targetRepsMin}–'
                                  '${exercise.targetRepsMax} repeticiones',
                                ),
                                Text(
                                  'Descanso: ${exercise.restSeconds} s',
                                ),
                                Text(
                                  'Calentamiento: ${exercise.warmupSets} · '
                                  'Aproximación: ${exercise.approachSets}',
                                ),
                                if (exercise.unilateral)
                                  const Text('Unilateral'),
                                if (exercise.supersetKey != null)
                                  Text(
                                    'Superserie: ${exercise.supersetKey}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        '${page.totalCount} '
                        '${widget.routineId == null ? 'rutinas' : 'ejercicios'} · '
                        'Página ${_offset ~/ CoachProProgramRevisionService.pageSize + 1}',
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _offset > 0
                                ? () => setState(
                                      () => _offset -=
                                          CoachProProgramRevisionService
                                              .pageSize,
                                    )
                                : null,
                            child: const Text('Anterior'),
                          ),
                          OutlinedButton(
                            onPressed: count > 0 &&
                                    _offset +
                                            CoachProProgramRevisionService
                                                .pageSize <
                                        page.totalCount &&
                                    _offset +
                                            CoachProProgramRevisionService
                                                .pageSize <=
                                        10000
                                ? () => setState(
                                      () => _offset +=
                                          CoachProProgramRevisionService
                                              .pageSize,
                                    )
                                : null,
                            child: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevisionComparison extends ConsumerWidget {
  final CoachProProgramRevisionPage current;
  final String relationshipId;
  final String assignmentId;

  const _RevisionComparison({
    required this.current,
    required this.relationshipId,
    required this.assignmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previousId = current.previousRevisionId;
    if (previousId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Primera captura disponible. No existe una revisión anterior '
            'contra la cual comparar.',
          ),
        ),
      );
    }

    final query = (
      relationshipId: relationshipId,
      assignmentId: assignmentId,
      revisionId: previousId,
      routineId: null,
      offset: 0,
    );
    final previous = ref.watch(
      coachProProgramRevisionDetailProvider(query),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: previous.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Comparando con la revisión anterior…'),
              ),
            ],
          ),
          error: (_, _) => const Text(
            'La comparación básica no está disponible ahora. '
            'La revisión actual sí puede consultarse.',
          ),
          data: (prior) {
            if (prior == null) {
              return const Text('La revisión anterior ya no está disponible.');
            }
            final changes = <String>[];
            if (prior.name != current.name) {
              changes.add('Nombre: ${prior.name} → ${current.name}');
            }
            if (prior.durationWeeks != current.durationWeeks) {
              changes.add(
                'Duración: ${prior.durationWeeks} → '
                '${current.durationWeeks} semanas',
              );
            }
            if (!_sameDays(prior.trainingWeekdays, current.trainingWeekdays)) {
              changes.add(
                'Días: ${_weekdays(prior.trainingWeekdays)} → '
                '${_weekdays(current.trainingWeekdays)}',
              );
            }
            if (!_sameDay(prior.startsOn, current.startsOn)) {
              changes.add(
                'Inicio: ${_shortDate(prior.startsOn)} → '
                '${_shortDate(current.startsOn)}',
              );
            }
            if (prior.totalCount != current.totalCount) {
              changes.add(
                'Rutinas: ${prior.totalCount} → '
                '${current.totalCount}',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparación básica con revisión '
                  '${prior.revisionNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (changes.isEmpty)
                  const Text(
                    'No hay cambios generales detectados. Puede haber cambios '
                    'dentro de las rutinas o prescripciones.',
                  )
                else
                  for (final change in changes) Text('• $change'),
                const SizedBox(height: 8),
                const Text(
                  'Esta comparación cubre datos generales y cantidad de '
                  'rutinas. Abre las rutinas para revisar la prescripción.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _authorLabel(CoachProProgramRevisionSource source) => switch (source) {
      CoachProProgramRevisionSource.legacyBaseline =>
        'histórico no disponible',
      CoachProProgramRevisionSource.coachRevision => 'coach asignado',
    };

String _date(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatMediumDate(value.toLocal());

String _shortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _weekdays(Set<int> days) {
  if (days.isEmpty) return 'Sin días definidos';
  const labels = <int, String>{
    DateTime.monday: 'Lun',
    DateTime.tuesday: 'Mar',
    DateTime.wednesday: 'Mié',
    DateTime.thursday: 'Jue',
    DateTime.friday: 'Vie',
    DateTime.saturday: 'Sáb',
    DateTime.sunday: 'Dom',
  };
  final sorted = days.toList()..sort();
  return sorted.map((day) => labels[day] ?? '?').join(', ');
}

bool _sameDays(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
