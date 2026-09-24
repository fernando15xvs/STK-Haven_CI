import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/coach/application/coach_program_assignment_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProgramAssignmentsPage extends ConsumerStatefulWidget {
  final String? clientUserId;
  final String? clientDisplayName;

  const CoachProgramAssignmentsPage({
    super.key,
    this.clientUserId,
    this.clientDisplayName,
  });

  @override
  ConsumerState<CoachProgramAssignmentsPage> createState() =>
      _CoachProgramAssignmentsPageState();
}

class _CoachProgramAssignmentsPageState
    extends ConsumerState<CoachProgramAssignmentsPage> {
  bool _requestedInitialLoad = false;

  void _scheduleRefresh(bool signedIn) {
    if (!signedIn || _requestedInitialLoad) return;
    _requestedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(coachProgramAssignmentsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(appIdentityProvider);
    final state = ref.watch(coachProgramAssignmentsProvider);
    final userId = identity.userId;
    final localPrograms = ref.watch(trainingProgramListProvider);
    _scheduleRefresh(identity.signedIn);

    ref.listen(coachProgramAssignmentsProvider, (previous, next) {
      if (next.message == null || next.message == previous?.message) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.message!)),
      );
    });

    final assignments = widget.clientUserId == null
        ? state.assignments
        : state.assignments
            .where((item) => item.clientUserId == widget.clientUserId)
            .toList(growable: false);

    final canAssignToSelectedClient = widget.clientUserId != null &&
        identity.signedIn &&
        assignments.any((item) => item.isCoach(userId)) ||
        (widget.clientUserId != null &&
            identity.signedIn &&
            assignments.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clientDisplayName?.trim().isNotEmpty == true
              ? 'Programas · ${widget.clientDisplayName}'
              : 'Programas asignados',
        ),
      ),
      floatingActionButton: widget.clientUserId != null &&
              identity.signedIn &&
              canAssignToSelectedClient
          ? FloatingActionButton.extended(
              onPressed: state.busy
                  ? null
                  : () => _showAssignDialog(
                        localPrograms: localPrograms,
                      ),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Asignar'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(coachProgramAssignmentsProvider.notifier)
                    .refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Las asignaciones contienen solo el programa prescrito. '
                        'No copian historial, PRs, medidas ni memoria de ejercicios '
                        'del entrenador.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!identity.signedIn)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Se necesita una cuenta permanente para recibir o '
                          'asignar programas.',
                        ),
                      ),
                    )
                  else if (state.operation ==
                          CoachProgramAssignmentOperation.loading &&
                      assignments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (assignments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay programas asignados todavía.'),
                      ),
                    )
                  else
                    for (final assignment in assignments) ...[
                      _AssignmentSummaryCard(
                        assignment: assignment,
                        currentUserId: userId,
                        busy: state.busy,
                        onOpen: () => _openAssignment(assignment),
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

  Future<void> _showAssignDialog({
    required List<TrainingProgram> localPrograms,
  }) async {
    final clientUserId = widget.clientUserId;
    if (clientUserId == null) return;
    if (localPrograms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea un programa local para poder asignarlo.'),
        ),
      );
      return;
    }

    var selectedProgramId = localPrograms.first.id;
    var startsOn = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Asignar programa'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedProgramId,
                  decoration: const InputDecoration(
                    labelText: 'Programa local',
                  ),
                  items: [
                    for (final program in localPrograms)
                      DropdownMenuItem(
                        value: program.id,
                        child: Text(program.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedProgramId = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Fecha de inicio'),
                  subtitle: Text(_dateLabel(startsOn)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 1)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                      initialDate: startsOn,
                    );
                    if (selected != null) {
                      setDialogState(() => startsOn = selected);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se enviará una instantánea del programa. Cambiar tu copia '
                  'local después no modifica lo que el cliente ya recibió.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(coachProgramAssignmentsProvider.notifier)
        .assignLocalProgram(
          clientUserId: clientUserId,
          programId: selectedProgramId,
          startsOn: startsOn,
        );
  }

  Future<void> _openAssignment(
    CoachProgramAssignmentSummary summary,
  ) async {
    final assignment = await ref
        .read(coachProgramAssignmentsProvider.notifier)
        .openAssignment(summary.id);
    if (!mounted || assignment == null) return;

    final userId = ref.read(appIdentityProvider).userId;
    final isClient = assignment.summary.isClient(userId);
    final canAccept = isClient &&
        assignment.summary.status == AssignedProgramStatus.assigned;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(assignment.summary.name),
        content: SizedBox(
          width: 620,
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: ListView(
            children: [
              _ProgramMetadata(assignment: assignment),
              const SizedBox(height: 14),
              for (final routine in assignment.routines) ...[
                Card(
                  child: ExpansionTile(
                    title: Text(routine.name),
                    subtitle: Text(
                      '${routine.exercises.length} ejercicio(s)',
                    ),
                    children: [
                      for (final exercise in routine.exercises)
                        ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.targetSets} × '
                            '${exercise.targetRepsMin}-'
                            '${exercise.targetRepsMax} · '
                            'descanso ${exercise.restSeconds}s',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (assignment.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Notas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(assignment.notes),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          if (canAccept)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _confirmInstall(summary.id);
              },
              icon: const Icon(Icons.download_done_outlined),
              label: const Text('Aceptar e instalar'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmInstall(String assignmentId) async {
    final activate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Instalar programa'),
        content: const Text(
          '¿Quieres instalarlo como tu programa activo? '
          'Tu historial anterior se conserva; solo cambia cuál programa '
          'queda activo para las próximas sesiones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Instalar sin activar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Instalar y activar'),
          ),
        ],
      ),
    );

    if (activate == null || !mounted) return;
    await ref
        .read(coachProgramAssignmentsProvider.notifier)
        .acceptAndInstall(
          assignmentId,
          activate: activate,
        );
  }
}

class _AssignmentSummaryCard extends StatelessWidget {
  final CoachProgramAssignmentSummary assignment;
  final String? currentUserId;
  final bool busy;
  final VoidCallback onOpen;

  const _AssignmentSummaryCard({
    required this.assignment,
    required this.currentUserId,
    required this.busy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final asCoach = assignment.isCoach(currentUserId);
    return Card(
      child: ListTile(
        leading: Icon(
          asCoach ? Icons.upload_outlined : Icons.download_outlined,
        ),
        title: Text(assignment.name),
        subtitle: Text(
          [
            asCoach ? 'Asignado por ti' : 'Asignado por entrenador',
            '${assignment.durationWeeks} semanas',
            'Inicio ${_dateLabel(assignment.startsOn)}',
          ].join(' · '),
        ),
        trailing: Chip(label: Text(_statusLabel(assignment.status))),
        onTap: busy ? null : onOpen,
      ),
    );
  }
}

class _ProgramMetadata extends StatelessWidget {
  final CoachProgramAssignment assignment;

  const _ProgramMetadata({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final weekdays = assignment.summary.trainingWeekdays.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${assignment.summary.durationWeeks} semanas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text('Inicio: ${_dateLabel(assignment.summary.startsOn)}'),
        if (weekdays.isNotEmpty)
          Text(
            'Días: ${weekdays.map(_weekdayLabel).join(', ')}',
          ),
        const SizedBox(height: 8),
        const Text(
          'Al instalar se crean IDs locales nuevos. '
          'El historial previo no se reescribe.',
        ),
      ],
    );
  }
}

String _statusLabel(AssignedProgramStatus status) => switch (status) {
      AssignedProgramStatus.assigned => 'Pendiente',
      AssignedProgramStatus.accepted => 'Aceptado',
      AssignedProgramStatus.archived => 'Archivado',
    };

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
