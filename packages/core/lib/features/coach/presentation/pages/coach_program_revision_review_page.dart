import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach/application/coach_program_revision_acceptance_provider.dart';
import 'package:core/features/coach/data/coach_program_revision_acceptance_service.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProgramRevisionReviewPage extends ConsumerStatefulWidget {
  final String assignmentId;
  final String revisionId;

  const CoachProgramRevisionReviewPage({
    super.key,
    required this.assignmentId,
    required this.revisionId,
  });

  @override
  ConsumerState<CoachProgramRevisionReviewPage> createState() =>
      _CoachProgramRevisionReviewPageState();
}

class _CoachProgramRevisionReviewPageState
    extends ConsumerState<CoachProgramRevisionReviewPage> {
  int _offset = 0;
  bool _accepting = false;

  ClientProgramRevisionPageQuery get _query => (
        assignmentId: widget.assignmentId,
        revisionId: widget.revisionId,
        routineId: null,
        offset: _offset,
      );

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(clientProgramRevisionPageProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Revisión propuesta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _RevisionError(
                message: 'No se pudo abrir esta revisión.',
                onRetry: () =>
                    ref.invalidate(clientProgramRevisionPageProvider(_query)),
              ),
              data: (value) {
                if (value == null) {
                  return const _RevisionError(
                    message: 'Se necesita una cuenta permanente.',
                  );
                }
                return _RevisionContent(
                  page: value,
                  offset: _offset,
                  accepting: _accepting,
                  onPrevious: _offset == 0
                      ? null
                      : () => setState(
                            () => _offset =
                                (_offset -
                                        CoachProgramRevisionAcceptanceService
                                            .pageSize)
                                    .clamp(0, 10000)
                                    .toInt(),
                          ),
                  onNext: _offset + value.routines.length >= value.totalCount
                      ? null
                      : () => setState(
                            () => _offset +=
                                CoachProgramRevisionAcceptanceService.pageSize,
                          ),
                  onOpenRoutine: (routine) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ClientProgramRevisionRoutinePage(
                          assignmentId: widget.assignmentId,
                          revisionId: widget.revisionId,
                          routine: routine,
                        ),
                      ),
                    );
                  },
                  onAccept: value.canAccept && !_accepting
                      ? () => _accept(value)
                      : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept(ClientProgramRevisionPage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Aceptar revisión ${page.revisionNumber}'),
        content: const Text(
          'Esto registra tu aceptación de esta revisión concreta. '
          'Todavía no instala, reemplaza ni activa ningún programa en este '
          'dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceptar revisión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _accepting = true);
    try {
      final result = await ref
          .read(coachProgramRevisionAcceptanceServiceProvider)
          .accept(
            assignmentId: widget.assignmentId,
            revisionId: widget.revisionId,
          );
      ref.invalidate(coachProgramRevisionStateProvider(widget.assignmentId));
      ref.invalidate(clientProgramRevisionPageProvider(_query));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyAccepted
                ? 'Esta revisión ya estaba aceptada.'
                : 'Revisión ${result.revisionNumber} aceptada. '
                    'Tu programa local todavía no cambió.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_acceptanceError(error))),
      );
      ref.invalidate(coachProgramRevisionStateProvider(widget.assignmentId));
      ref.invalidate(clientProgramRevisionPageProvider(_query));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo aceptar la revisión.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}

class _RevisionContent extends StatelessWidget {
  final ClientProgramRevisionPage page;
  final int offset;
  final bool accepting;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<ClientProgramRevisionRoutineSummary> onOpenRoutine;
  final VoidCallback? onAccept;

  const _RevisionContent({
    required this.page,
    required this.offset,
    required this.accepting,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenRoutine,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final weekdays = page.trainingWeekdays.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        page.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        page.isAccepted
                            ? 'Aceptada'
                            : 'Revisión ${page.revisionNumber}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${page.durationWeeks} semanas · '
                  'Inicio ${_dateLabel(page.startsOn)}',
                ),
                if (weekdays.isNotEmpty)
                  Text('Días: ${weekdays.map(_weekdayLabel).join(', ')}'),
                Text('Propuesta: ${_dateLabel(page.displayDate)}'),
                const SizedBox(height: 12),
                const Text(
                  'Aceptar esta revisión solo registra tu consentimiento. '
                  'No cambia, instala ni activa el programa local.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Rutinas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (page.routines.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Esta página no contiene rutinas.'),
            ),
          )
        else
          for (final routine in page.routines)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text(routine.name),
                subtitle: const Text('Ver prescripción de ejercicios'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenRoutine(routine),
              ),
            ),
        const SizedBox(height: 12),
        _Pagination(
          offset: offset,
          totalCount: page.totalCount,
          visibleCount: page.routines.length,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        if (page.isAccepted) ...[
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Revisión aceptada'),
              subtitle: Text(
                'La instalación local se realizará en un paso separado.',
              ),
            ),
          ),
        ] else if (page.canAccept) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: accepting ? null : onAccept,
            icon: accepting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(
              accepting
                  ? 'Aceptando…'
                  : 'Aceptar revisión ${page.revisionNumber}',
            ),
          ),
        ],
      ],
    );
  }
}

class _ClientProgramRevisionRoutinePage extends ConsumerStatefulWidget {
  final String assignmentId;
  final String revisionId;
  final ClientProgramRevisionRoutineSummary routine;

  const _ClientProgramRevisionRoutinePage({
    required this.assignmentId,
    required this.revisionId,
    required this.routine,
  });

  @override
  ConsumerState<_ClientProgramRevisionRoutinePage> createState() =>
      _ClientProgramRevisionRoutinePageState();
}

class _ClientProgramRevisionRoutinePageState
    extends ConsumerState<_ClientProgramRevisionRoutinePage> {
  int _offset = 0;

  ClientProgramRevisionPageQuery get _query => (
        assignmentId: widget.assignmentId,
        revisionId: widget.revisionId,
        routineId: widget.routine.id,
        offset: _offset,
      );

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(clientProgramRevisionPageProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _RevisionError(
                message: 'No se pudo cargar la prescripción.',
                onRetry: () =>
                    ref.invalidate(clientProgramRevisionPageProvider(_query)),
              ),
              data: (value) {
                if (value == null) {
                  return const _RevisionError(
                    message: 'Se necesita una cuenta permanente.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  children: [
                    for (final exercise in value.exercises)
                      Card(
                        child: ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(_exercisePrescription(exercise)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _Pagination(
                      offset: _offset,
                      totalCount: value.totalCount,
                      visibleCount: value.exercises.length,
                      onPrevious: _offset == 0
                          ? null
                          : () => setState(
                                () => _offset =
                                    (_offset -
                                            CoachProgramRevisionAcceptanceService
                                                .pageSize)
                                        .clamp(0, 10000)
                                        .toInt(),
                              ),
                      onNext:
                          _offset + value.exercises.length >= value.totalCount
                              ? null
                              : () => setState(
                                    () => _offset +=
                                        CoachProgramRevisionAcceptanceService
                                            .pageSize,
                                  ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int offset;
  final int totalCount;
  final int visibleCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Pagination({
    required this.offset,
    required this.totalCount,
    required this.visibleCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final first = totalCount == 0 ? 0 : offset + 1;
    final last = (offset + visibleCount).clamp(0, totalCount);
    return Row(
      children: [
        Expanded(child: Text('$first–$last de $totalCount')),
        TextButton(
          onPressed: onPrevious,
          child: const Text('Anterior'),
        ),
        TextButton(
          onPressed: onNext,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}

class _RevisionError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _RevisionError({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _exercisePrescription(AssignedExerciseSnapshot exercise) {
  final details = <String>[
    '${exercise.targetSets} series · '
        '${exercise.targetRepsMin}–${exercise.targetRepsMax} repeticiones',
    'Descanso efectivo ${exercise.restSeconds}s',
  ];
  if (exercise.warmupSets > 0) {
    details.add(
      'Calentamiento: ${exercise.warmupSets} · '
      '${exercise.warmupRestSeconds ?? exercise.restSeconds}s',
    );
  }
  if (exercise.approachSets > 0) {
    details.add(
      'Aproximación: ${exercise.approachSets} · '
      '${exercise.approachRestSeconds ?? exercise.restSeconds}s',
    );
  }
  if (exercise.unilateral) {
    details.add(
      exercise.preparationUnilateral
          ? 'Preparación unilateral'
          : 'Preparación bilateral',
    );
    if (exercise.unilateralSideRestSeconds != null) {
      details.add(
        'Entre lados: ${exercise.unilateralSideRestSeconds}s',
      );
    }
  }
  return details.join('\n');
}

String _acceptanceError(PostgrestException error) {
  final raw = error.message.toLowerCase();
  if (raw.contains('program revision changed')) {
    return 'El entrenador publicó una revisión más reciente. Vuelve a cargar.';
  }
  if (raw.contains('coach pro entitlement required') ||
      raw.contains('revision acceptance unavailable')) {
    return 'Esta revisión ya no está disponible para aceptar.';
  }
  return 'No se pudo aceptar la revisión.';
}

String _weekdayLabel(int weekday) => switch (weekday) {
      DateTime.monday => 'Lun',
      DateTime.tuesday => 'Mar',
      DateTime.wednesday => 'Mié',
      DateTime.thursday => 'Jue',
      DateTime.friday => 'Vie',
      DateTime.saturday => 'Sáb',
      DateTime.sunday => 'Dom',
      _ => '?',
    };

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
