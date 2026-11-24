import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/application/coach_pro_program_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_program_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProProgramDetailPage extends ConsumerWidget {
  final String relationshipId;
  final String assignmentId;
  final int version;
  final String? routineId;
  const CoachProProgramDetailPage({super.key, required this.relationshipId,
    required this.assignmentId, required this.version, this.routineId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(appBar: AppBar(title: Text(routineId == null ? 'Programa asignado' : 'Rutina asignada')),
      body: !identity.signedIn || identity.userId == null
        ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
        : _Program(key: ValueKey(identity.userId), relationshipId: relationshipId,
            assignmentId: assignmentId, version: version, routineId: routineId));
  }
}

class _Program extends ConsumerStatefulWidget {
  final String relationshipId, assignmentId;
  final int version;
  final String? routineId;
  const _Program({super.key, required this.relationshipId,
    required this.assignmentId, required this.version, this.routineId});
  @override
  ConsumerState<_Program> createState() => _ProgramState();
}
class _ProgramState extends ConsumerState<_Program> with WidgetsBindingObserver {
  int _offset = 0;
  CoachProProgramQuery get _query => (relationshipId: widget.relationshipId,
    assignmentId: widget.assignmentId, version: widget.version,
    routineId: widget.routineId, offset: _offset);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }
  void _refresh() => ref.invalidate(coachProProgramPageProvider(_query));
  Future<void> _openRoutine(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      CoachProProgramDetailPage(relationshipId: widget.relationshipId,
        assignmentId: widget.assignmentId, version: widget.version, routineId: id)));
    if (mounted) _refresh();
  }
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProProgramPageProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: result.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
        result.when(skipLoadingOnRefresh: false, skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo consultar esta versión. Revisa la conexión y los permisos. '
                'Si el programa cambió, vuelve a la ficha y ábrelo de nuevo.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (page) {
            if (page == null) return const Text('Programa no disponible.');
            final count = widget.routineId == null ? page.routines.length : page.exercises.length;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(page.name, style: Theme.of(context).textTheme.headlineSmall),
              Text('Versión ${page.version} · ${_status(page.status)}'),
              if (page.routineName != null)
                Text(page.routineName!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (count == 0) Text(_offset == 0 ? 'No hay elementos en esta sección.'
                  : 'Esta página está vacía. Vuelve a la anterior.'),
              for (final routine in page.routines)
                Card(child: ListTile(title: Text(routine.name),
                  subtitle: Text('Rutina ${routine.position + 1}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openRoutine(routine.id))),
              for (final exercise in page.exercises)
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
                    Text('${exercise.targetSets} series · ${exercise.targetRepsMin}–${exercise.targetRepsMax} repeticiones'),
                    Text('Descanso: ${exercise.restSeconds} s'),
                    Text('Calentamiento: ${exercise.warmupSets} · Aproximación: ${exercise.approachSets}'),
                    if (exercise.unilateral) const Text('Unilateral'),
                    if (exercise.supersetKey != null) Text('Superserie: ${exercise.supersetKey}'),
                  ]),
                )),
              const SizedBox(height: 12),
              Text('${page.totalCount} ${widget.routineId == null ? 'rutinas' : 'ejercicios'} · Página ${_offset ~/ 25 + 1}'),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton(onPressed: _offset > 0 ? () => setState(() => _offset -= 25) : null,
                  child: const Text('Anterior')),
                OutlinedButton(onPressed: count > 0 && _offset + 25 < page.totalCount && _offset + 25 <= 10000
                    ? () => setState(() => _offset += 25) : null, child: const Text('Siguiente')),
              ]),
            ]);
          }),
      ]),
    )));
  }
}
String _status(AssignedProgramStatus status) => switch (status) {
  AssignedProgramStatus.assigned => 'Asignado',
  AssignedProgramStatus.accepted => 'Aceptado',
  AssignedProgramStatus.archived => 'Archivado',
};
