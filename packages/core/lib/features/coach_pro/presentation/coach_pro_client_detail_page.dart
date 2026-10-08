import 'package:core/features/coach_pro/presentation/coach_pro_task_page.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_nutrition_page.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_program_page.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_templates_page.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_program_revision_page.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach_pro/application/coach_pro_client_detail_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachProClientDetailPage extends ConsumerWidget {
  final String relationshipId;
  const CoachProClientDetailPage({super.key, required this.relationshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha Coach Pro')),
      body: !identity.signedIn || identity.userId == null
          ? const Center(child: Text('Inicia sesión con una cuenta permanente.'))
          : _Detail(key: ValueKey(identity.userId), relationshipId: relationshipId),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  final String relationshipId;
  const _Detail({super.key, required this.relationshipId});
  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> with WidgetsBindingObserver {
  CoachProClientSection _section = CoachProClientSection.summary;
  int _offset = 0;
  CoachProClientDetailQuery get _query =>
      (relationshipId: widget.relationshipId, section: _section, offset: _offset);

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
  void _refresh() => ref.invalidate(coachProClientDetailProvider(_query));

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(coachProClientDetailProvider(_query));
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Wrap(spacing: 12, runSpacing: 8, children: [
          for (final section in CoachProClientSection.values)
            ChoiceChip(label: Text(_sectionLabel(section)), selected: _section == section,
              onSelected: (_) => setState(() { _section = section; _offset = 0; })),
          TextButton.icon(onPressed: result.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
        ]),
        const SizedBox(height: 20),
        result.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(children: [
            const Text('No se pudo consultar la ficha. Comprueba la conexión y '
                'tu acceso vigente; el cliente puede haber cambiado sus permisos.'),
            TextButton(onPressed: _refresh, child: const Text('Reintentar')),
          ]),
          data: (detail) {
            if (detail == null) return const Text('La relación no está disponible.');
            final summary = detail.summary;
            final progress = summary.relationshipStatus == CoachRelationshipStatus.active &&
                summary.permissions.contains(CoachPermission.viewProgress);
            String metric(Object? value) => !progress ? 'No compartido'
                : value?.toString() ?? 'Sin datos';
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(summary.displayName.trim().isEmpty ? 'Cliente' : summary.displayName,
                style: Theme.of(context).textTheme.headlineSmall),
              Text(summary.relationshipStatus == CoachRelationshipStatus.active
                  ? 'Relación activa' : 'Relación pausada'),
              const SizedBox(height: 16),
              if (_section == CoachProClientSection.summary) ...[
                Text('Entrenos 7 días: ${metric(summary.workouts7d)}'),
                Text('Entrenos 30 días: ${metric(summary.workouts30d)}'),
                Text('RIR medio 7 días: ${metric(summary.averageRir7d)}'),
                Text('Último entreno: ${!progress ? 'No compartido' : _date(context, summary.lastWorkoutAt)}'),
                const SizedBox(height: 16),
                const Text('Los permisos los administra el cliente. El plan Coach Pro '
                    'no concede acceso adicional a sus datos.'),
              ] else if (_section == CoachProClientSection.nutrition) ...[
                if (!detail.canViewNutrition)
                  const Text('Orientación alimentaria: no compartida en esta relación.')
                else ...[
                  const Text(NutritionGuidancePlan.defaultScopeNotice),
                  if (detail.nutrition!.items.isEmpty)
                    Text(_offset == 0 ? 'No hay orientaciones alimentarias compartidas.'
                      : 'Esta página está vacía. Vuelve a la anterior.'),
                  for (final item in detail.nutrition!.items)
                    Card(child: Padding(padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title),
                        Text('${item.status == NutritionGuidanceStatus.active ? 'Activa' : 'Archivada'} · Versión ${item.currentVersion}'),
                        TextButton(onPressed: () async {
                          await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) =>
                            CoachProNutritionDetailPage(query: (relationshipId: widget.relationshipId,
                              clientUserId: summary.clientUserId, planId: item.id, version: item.currentVersion, offset: 0))));
                          if (mounted) _refresh();
                        }, child: const Text('Ver orientación')),
                      ]))),
                  _pagination(detail.nutrition!.items.length, detail.nutrition!.totalCount, 'orientaciones'),
                ],
              ] else if (_section == CoachProClientSection.progress) ...[
                if (!detail.canViewProgress)
                  const Text('Progreso: no compartido en esta relación.')
                else if (detail.progress == null)
                  const Text('Todavía no hay una instantánea de progreso compartida.')
                else ...[
                  Text('Instantánea generada: ${_date(context, detail.progress!.generatedAt)}'),
                  const Text('Los periodos de 7 y 30 días corresponden a esa instantánea. Actualizar consulta lo último compartido; no recalcula la actividad del cliente.'),
                  Text('Entrenos en 7 días: ${detail.progress!.workouts7d}'),
                  Text('Entrenos en 30 días: ${detail.progress!.workouts30d}'),
                  Text('Minutos de entrenamiento en 7 días: ${detail.progress!.trainingMinutes7d}'),
                  Text('Series de trabajo en 7 días: ${detail.progress!.completedWorkingSets7d}'),
                  Text('Volumen registrado en 7 días: ${detail.progress!.volume7d}'),
                  Text('RIR medio en 7 días: ${detail.progress!.averageRir7d?.toString() ?? 'Sin datos'}'),
                  Text('Último entreno registrado: ${_date(context, detail.progress!.lastWorkoutAt)}'),
                  const SizedBox(height: 16),
                  Text(
                    'Tendencia reciente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (!detail.progress!.trendBaselineAvailable)
                    const Text(
                      'Aún no hay una ventana anterior comparable. '
                      'Se mostrará cuando el cliente vuelva a sincronizar '
                      'con el nuevo contrato de progreso.',
                    )
                  else ...[
                    Text(
                      'Entrenos: ${_trend(detail.progress!.workoutsTrendDelta7d)} '
                      'vs. los 7 días anteriores',
                    ),
                    Text(
                      'Minutos: ${_trend(detail.progress!.trainingMinutesTrendDelta7d)} '
                      'vs. los 7 días anteriores',
                    ),
                    Text(
                      'Series efectivas: ${_trend(detail.progress!.workingSetsTrendDelta7d)} '
                      'vs. los 7 días anteriores',
                    ),
                    Text(
                      'Volumen: ${_trendNumber(detail.progress!.volumeTrendDelta7d)} '
                      'vs. los 7 días anteriores',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Adherencia de frecuencia',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (detail.progress!.frequencyAdherence == null)
                    const Text(
                      'Sin cálculo disponible. Requiere un programa aceptado '
                      'de este coach y permiso vigente para programas.',
                    )
                  else ...[
                    Text(
                      '${detail.progress!.frequencyAdherence!.assignmentName} · '
                      '7 días: ${_adherence(detail.progress!.frequencyAdherence!.percent7d)} '
                      '(${detail.progress!.frequencyAdherence!.completedSessions7d}/'
                      '${detail.progress!.frequencyAdherence!.scheduledSessions7d})',
                    ),
                    Text(
                      '30 días: ${_adherence(detail.progress!.frequencyAdherence!.percent30d)} '
                      '(${detail.progress!.frequencyAdherence!.completedSessions30d}/'
                      '${detail.progress!.frequencyAdherence!.scheduledSessions30d})',
                    ),
                    const Text(
                      'Compara frecuencia planificada vs. entrenamientos '
                      'registrados; no confirma que se haya realizado la '
                      'rutina exacta prescrita.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Las tendencias comparan dos ventanas de 7 días. '
                    'No representan por sí solas mejora de fuerza, hipertrofia '
                    'ni un récord personal.',
                  ),
                ],
              ] else if (_section == CoachProClientSection.exerciseProgress) ...[
                if (!detail.canViewExerciseProgress)
                  const Text(
                    'Tendencias por ejercicio: requieren que el cliente '
                    'comparta progreso y entrenamientos en esta relación.',
                  )
                else ...[
                  const Text(
                    'Agregados por ejercicio: últimos 30 días frente a los '
                    '30 días anteriores. No incluye notas ni series '
                    'individuales.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Los PRs muestran el mejor valor observado en el historial '
                    'compartido. El 1RM es una estimación, no una prueba de 1RM.',
                  ),
                  if (detail.exerciseProgress!.items.isEmpty)
                    Text(
                      _offset == 0
                          ? 'Todavía no hay tendencias por ejercicio compartidas.'
                          : 'Esta página está vacía. Vuelve a la anterior.',
                    ),
                  for (final item in detail.exerciseProgress!.items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.exerciseName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (item.muscleGroup.isNotEmpty)
                              Text(item.muscleGroup),
                            Text(
                              'Última sesión: ${_date(context, item.lastPerformedAt)}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sesiones 30d: ${item.sessions30d} '
                              '(${_trend(item.sessionsDelta30d)} vs. periodo anterior)',
                            ),
                            Text(
                              'Series efectivas 30d: ${item.workingSets30d} '
                              '(${_trend(item.workingSetsDelta30d)})',
                            ),
                            Text(
                              'Volumen 30d: ${_number(item.volume30d)} '
                              '(${_trendNumber(item.volumeDelta30d)})',
                            ),
                            Text(
                              'RIR medio 30d: '
                              '${item.averageRir30d == null ? 'Sin datos' : _number(item.averageRir30d!)}',
                            ),
                            Text(
                              'Mejor e1RM 30d: '
                              '${_optionalNumber(item.bestEstimated1Rm30d)} · '
                              '30d anteriores: '
                              '${_optionalNumber(item.bestEstimated1RmPrevious30d)}'
                              '${item.estimated1RmDelta30d == null ? '' : ' '
                                  '(${_trendNumber(item.estimated1RmDelta30d!)})'}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PR peso: ${_optionalNumber(item.bestWeight)}'
                              '${item.bestWeightAt == null ? '' : ' · '
                                  '${_date(context, item.bestWeightAt)}'}',
                            ),
                            Text(
                              'PR e1RM: ${_optionalNumber(item.bestEstimated1Rm)}'
                              '${item.bestEstimated1RmAt == null ? '' : ' · '
                                  '${_date(context, item.bestEstimated1RmAt)}'}',
                            ),
                            Text(
                              'PR volumen de serie: '
                              '${_optionalNumber(item.bestSetVolume)}'
                              '${item.bestSetVolumeAt == null ? '' : ' · '
                                  '${_date(context, item.bestSetVolumeAt)}'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  _pagination(
                    detail.exerciseProgress!.items.length,
                    detail.exerciseProgress!.totalCount,
                    'ejercicios',
                  ),
                ],
              ] else if (_section == CoachProClientSection.workouts) ...[
                if (!detail.canViewWorkouts)
                  const Text('Entrenamientos: no compartidos en esta relación.')
                else ...[
                  const Text('Resúmenes recientes compartidos (hasta 30). No es el historial completo; no incluye notas ni series individuales.'),
                  if (detail.workouts!.items.isEmpty)
                    Text(_offset == 0 ? 'Todavía no hay resúmenes de entrenamientos compartidos.'
                        : 'Esta página está vacía. Vuelve a la anterior.'),
                  for (final item in detail.workouts!.items)
                    Card(child: Padding(padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.routineName.isEmpty ? 'Entrenamiento' : item.routineName,
                          style: Theme.of(context).textTheme.titleMedium),
                        Text(_date(context, item.startedAt)),
                        Text('Duración registrada: ${item.durationSeconds ~/ 60} min'),
                        Text('Series de trabajo: ${item.completedWorkingSets}/${item.plannedWorkingSets}'),
                        Text('Completado: ${item.completionPercent}%'),
                        Text('Volumen registrado: ${item.volume}'),
                        Text('RIR medio: ${item.averageRir?.toString() ?? 'Sin datos'}'),
                      ]),
                    )),
                  _pagination(detail.workouts!.items.length, detail.workouts!.totalCount, 'resúmenes'),
                ],
              ] else if (_section == CoachProClientSection.programs) ...[
                if (!detail.canViewPrograms)
                  const Text('Programas: no compartidos en esta relación.')
                else ...[
                  Align(alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text('Asignar desde plantillas'),
                      onPressed: () async {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => CoachProTemplatesPage(
                            relationshipId: widget.relationshipId,
                          )),
                        );
                        if (mounted) _refresh();
                      },
                    ),
                  ),
                  if (detail.programs!.items.isEmpty)
                    Text(_offset == 0 ? 'No hay programas asignados en esta relación.'
                        : 'Esta página ya no tiene programas. Vuelve a la anterior.'),
                  for (final item in detail.programs!.items)
                    Card(child: Padding(padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          TextButton(onPressed: () => _openProgram(item),
                            child: const Text('Ver rutinas')),
                          TextButton(onPressed: () => _openProgramHistory(item),
                            child: const Text('Historial de revisiones')),
                        ]),
                        Text('${_programStatus(item.status)} · Versión ${item.version}'),
                        Text('${item.durationWeeks} semanas · Inicio: ${_date(context, item.startsOn)}'),
                      ]),
                    )),
                  _pagination(detail.programs!.items.length, detail.programs!.totalCount, 'programas'),
                ],
              ] else if (_section == CoachProClientSection.tasks) ...[
                if (!detail.canViewTasks)
                  const Text('Tareas: no compartidas en esta relación.')
                else ...[
                  if (detail.tasks!.items.isEmpty)
                    Text(_offset == 0 ? 'No hay tareas asignadas en esta relación.'
                        : 'Esta página ya no tiene tareas. Vuelve a la anterior.'),
                  for (final item in detail.tasks!.items)
                    Card(child: Padding(padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                        TextButton(onPressed: () => _openTask(item.id),
                          child: const Text('Ver historial')),
                        Text('${item.category} · ${item.status == CoachAssignedTaskStatus.active ? 'Activa' : 'Archivada'}'),
                        Text('Inicio: ${_date(context, item.startsOn)}'),
                        if (item.dueAt != null) Text('Vencimiento: ${_date(context, item.dueAt)}'),
                      ]),
                    )),
                  _pagination(detail.tasks!.items.length, detail.tasks!.totalCount, 'tareas'),
                ],
              ] else if (!detail.canViewCheckins)
                const Text('Check-ins: no compartidos en esta relación.')
              else ...[
                if (detail.checkins!.items.isEmpty)
                  Text(_offset == 0 ? 'Todavía no hay check-ins compartidos.'
                      : 'Esta página ya no tiene check-ins. Vuelve a la anterior.'),
                for (final item in detail.checkins!.items)
                  Card(child: Padding(padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_date(context, item.createdAt)),
                      Text('Energía: ${item.energy} · Recuperación: ${item.recovery}'),
                      if (item.note.isNotEmpty) Text(item.note),
                    ]),
                  )),
                _pagination(detail.checkins!.items.length, detail.checkins!.totalCount, 'check-ins'),
              ],
            ]);
          },
        ),
      ]),
    )));
  }

  Future<void> _openTask(String taskId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      CoachProTaskDetailPage(relationshipId: widget.relationshipId, taskId: taskId)));
    if (mounted) _refresh();
  }

  Future<void> _openProgram(CoachProgramAssignmentSummary program) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      CoachProProgramDetailPage(relationshipId: widget.relationshipId,
        assignmentId: program.id, version: program.version)));
    if (mounted) _refresh();
  }

  Future<void> _openProgramHistory(
    CoachProgramAssignmentSummary program,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachProProgramRevisionHistoryPage(
          relationshipId: widget.relationshipId,
          assignmentId: program.id,
          assignmentName: program.name,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Widget _pagination(int count, int? total, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(total == null ? 'Página ${_offset ~/ 25 + 1}'
          : '$total $label · Página ${_offset ~/ 25 + 1}'),
      Wrap(spacing: 12, runSpacing: 8, children: [
        OutlinedButton(onPressed: _offset > 0
            ? () => setState(() => _offset -= 25) : null,
          child: const Text('Anterior')),
        OutlinedButton(onPressed: count > 0 && _offset + 25 < (total ?? 0) &&
            _offset + 25 <= 10000 ? () => setState(() => _offset += 25) : null,
          child: const Text('Siguiente')),
      ]),
    ],
  );

}

String _date(BuildContext context, DateTime? value) => value == null ? 'Sin datos'
    : MaterialLocalizations.of(context).formatMediumDate(value.toLocal());


String _sectionLabel(CoachProClientSection section) => switch (section) {
  CoachProClientSection.summary => 'Resumen',
  CoachProClientSection.checkins => 'Check-ins',
  CoachProClientSection.programs => 'Programas',
  CoachProClientSection.tasks => 'Tareas',
  CoachProClientSection.workouts => 'Entrenamientos',
  CoachProClientSection.progress => 'Progreso',
  CoachProClientSection.exerciseProgress => 'Ejercicios',
  CoachProClientSection.nutrition => 'Alimentación',
};
String _programStatus(AssignedProgramStatus status) => switch (status) {
  AssignedProgramStatus.assigned => 'Asignado',
  AssignedProgramStatus.accepted => 'Aceptado',
  AssignedProgramStatus.archived => 'Archivado',
};


String _trend(int value) {
  if (value > 0) return '+$value';
  return value.toString();
}

String _trendNumber(double value) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  final formatted = normalized.toStringAsFixed(
    normalized == normalized.truncateToDouble() ? 0 : 1,
  );
  return normalized > 0 ? '+$formatted' : formatted;
}

String _adherence(int? value) => value == null ? 'Sin meta' : '$value%';


String _number(double value) {
  if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _optionalNumber(double? value) =>
    value == null ? 'Sin datos' : _number(value);
