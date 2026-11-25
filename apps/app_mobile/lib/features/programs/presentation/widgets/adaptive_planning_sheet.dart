import 'package:core/domain/models/program_adaptation.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

typedef _PlanCommand = TrainingProgram Function(TrainingProgram, List<Routine>, DateTime);

class PlanningStart {
  const PlanningStart(this.routineId, this.occurrenceId);
  final String routineId;
  final String occurrenceId;
}

/// UI only: all transitions are delegated to Core. Opening the sheet is
/// read-only; only confirmed commands persist an adaptation.
class AdaptivePlanningSheet extends ConsumerStatefulWidget {
  const AdaptivePlanningSheet({super.key});
  static Future<PlanningStart?> show(BuildContext context) =>
    showModalBottomSheet<PlanningStart>(context: context, useSafeArea: true,
      isScrollControlled: true, showDragHandle: true,
      builder: (_) => const AdaptivePlanningSheet());

  @override
  ConsumerState<AdaptivePlanningSheet> createState() => _AdaptivePlanningSheetState();
}

class _AdaptivePlanningSheetState extends ConsumerState<AdaptivePlanningSheet> {
  bool _busy = false;
  bool _nextWeek = false;
  bool _showActions = false;
  String? _error;

  Future<bool> _confirm(String title, String message) async =>
    await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
      ])) == true;

  Future<void> _apply(String title, String description, _PlanCommand command) async {
    if (_busy || !await _confirm(title, description) || !mounted) return;
    final expected = ref.read(activeTrainingProgramProvider)?.id;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(trainingProgramListProvider.notifier).adaptActive((p,r,n) {
        if (p.id != expected) throw StateError('El programa activo cambió.');
        return command(p,r,n);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo aplicar el cambio. Revisa las sesiones pendientes.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PlanOccurrence?> _choose(String title, List<PlanOccurrence> rows,
      Map<String,Routine> byId) => showDialog<PlanOccurrence>(context: context,
    builder: (ctx) => SimpleDialog(title: Text(title), children: [
      for (final (index, row) in rows.indexed)
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, row),
          child: Text('${index+1}. ${byId[row.routineId]?.name ?? 'Rutina no disponible'}'
            '${row.date == null ? '' : ' · ${DateFormat('d/M').format(row.date!)}'}')),
    ]));

  Future<void> _pauseRoutines(List<Routine> routines) async {
    final selected = <String>{};
    final ids = await showDialog<Set<String>>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, change) => AlertDialog(title: const Text('Pausar rutinas'),
        content: SizedBox(width: 360, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            for (final routine in routines)
              CheckboxListTile(value: selected.contains(routine.id),
                title: Text(routine.name), onChanged: (v) => change(() {
                  if (v == true) { selected.add(routine.id); } else { selected.remove(routine.id); }
                })),
          ]))), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected),
            child: const Text('Continuar')),
        ])));
    if (ids != null && mounted) await _pause(ids);
  }

  Future<void> _pause(Set<String>? ids) async {
    final choice = await showDialog<String>(context: context, builder: (ctx) =>
      SimpleDialog(title: Text(ids == null ? 'Pausar programa' : 'Duración de la pausa'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'manual'),
          child: const Text('Hasta que decida reanudar')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'date'),
          child: const Text('Hasta una fecha')),
      ]));
    if (choice == null || !mounted) return;
    DateTime? until;
    if (choice == 'date') {
      final now = DateTime.now();
      final tomorrow = TrainingProgram.shiftCalendarDays(now, 1);
      until = await showDatePicker(context: context, initialDate: tomorrow,
        firstDate: tomorrow, lastDate: TrainingProgram.shiftCalendarDays(now, 365));
      if (until == null || !mounted) return;
    }
    await _apply('Confirmar pausa', 'Se conserva tu historial. Las rutinas pausadas no se sugerirán.',
      (p,r,n) => ProgramAdaptationPolicy.pause(p,r,n,routineIds: ids,until: until));
  }

  Future<void> _slotActions(TrainingProgram prepared, PlanOccurrence row,
      List<PlanOccurrence> pending, Map<String,Routine> byId, DateTime now) async {
    final name = byId[row.routineId]?.name ?? 'Rutina';
    final action = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: Text(name), children: [
        if (row.status == PlanOccurrenceStatus.omitted)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'restore'), child: const Text('Restaurar sesión')),
        if (row.status == PlanOccurrenceStatus.pending) ...[
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'postpone'), child: const Text('Posponer sesión')),
          if (pending.any((o) => o.id != row.id))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'swap'), child: const Text('Intercambiar sesión')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'recover'), child: const Text('Recuperar hoy y desplazar pendientes')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'omit'), child: const Text('Omitir sesión')),
          if (!prepared.adaptation!.routinePausedAt(row.routineId, now) &&
              !ProgramWeekPlan.calculate(program: prepared, routines: ref.read(routineListProvider), now: now).goalReached &&
              ProgramAdaptationPolicy.availableDate(prepared, ref.read(routineListProvider), row, now) == ProgramAdaptationPolicy.day(now))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'start'), child: const Text('Entrenar esta sesión')),
        ],
      ]));
    if (action == null || !mounted) return;
    switch (action) {
      case 'postpone':
        final today = ProgramAdaptationPolicy.day(now);
        final tomorrow = TrainingProgram.shiftCalendarDays(today, 1);
        final end = (prepared.repeatsWeekly || prepared.scheduleMode == ProgramScheduleMode.fixed)
            ? TrainingProgram.shiftCalendarDays(prepared.adaptation!.week, 6)
            : TrainingProgram.shiftCalendarDays(today, 365);
        if (tomorrow.isAfter(end)) {
          setState(() => _error = 'Esta semana termina hoy. Puedes recuperar la sesión la próxima semana.');
          return;
        }
        final date = await showDatePicker(context: context, initialDate: tomorrow,
          firstDate: tomorrow, lastDate: end);
        if (date != null && mounted) await _apply('Posponer sesión', '$name quedará pendiente hasta la fecha elegida.',
          (p,r,n) => ProgramAdaptationPolicy.postpone(p,r,row.id,n,date));
        break;
      case 'swap':
        final other = await _choose('Intercambiar con', pending.where((o) => o.id != row.id).toList(), byId);
        if (other != null && mounted) await _apply('Intercambiar sesiones',
          'Cambiará el orden de ambas sesiones, no la plantilla ni el historial.',
          (p,r,n) => ProgramAdaptationPolicy.exchange(p,r,row.id,other.id,n));
        break;
      case 'recover':
        await _apply('Recuperar sesión', 'Esta sesión se priorizará hoy y las pendientes podrán desplazarse.',
          (p,r,n) => ProgramAdaptationPolicy.recover(p,r,row.id,n,shiftFollowing:true));
        break;
      case 'omit':
        await _apply('Omitir sesión', 'No contará como completada. Puedes restaurarla durante esta semana.',
          (p,r,n) => ProgramAdaptationPolicy.omit(p,r,row.id,n));
        break;
      case 'restore':
        await _apply('Restaurar sesión', 'Volverá a estar pendiente.',
          (p,r,n) => ProgramAdaptationPolicy.restoreOmitted(p,r,row.id,n));
        break;
      case 'start':
        // Persist the prepared identity before returning it to the launcher.
        if (!await _confirm('Entrenar esta sesión', 'Se vinculará a esta posición del programa. No se alterará el historial.') || !mounted) return;
        try {
          await ref.read(trainingProgramListProvider.notifier).adaptActive((p,r,n) =>
            ProgramAdaptationPolicy.prepare(p,r,n));
          if (mounted) Navigator.pop(context, PlanningStart(row.routineId,row.id));
        } catch (_) {
          if (mounted) setState(() => _error = 'No se pudo preparar la sesión.');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeTrainingProgramProvider);
    final routines = ref.watch(routineListProvider);
    final history = ref.watch(workoutHistoryProvider);
    final now = ref.watch(trainingDayClockProvider);
    final colors = AppColors.of(context);
    if (active == null) return const SafeArea(child: Padding(
      padding: EdgeInsets.all(24), child: Text('No hay programa activo.')));
    final prepared = ProgramAdaptationPolicy.prepare(
      ProgramRotationCoordinator.reconcile(active, history), routines, now);
    final plan = ProgramWeekPlan.calculate(program: prepared,routines:routines,now:now);
    final state = prepared.adaptation!;
    final rows = ProgramAdaptationPolicy.current(prepared);
    final pending = rows.where((o) => o.status == PlanOccurrenceStatus.pending &&
      !state.bindings.containsValue(o.id)).toList();
    final past = state.occurrences.where((o) => !o.archived && o.week.isBefore(state.week) &&
      (o.status == PlanOccurrenceStatus.expired || o.status == PlanOccurrenceStatus.omitted) &&
      prepared.routineIds.contains(o.routineId)).toList().reversed.toList();
    final byId = {for (final r in routines) r.id:r};
    final flexible = active.scheduleMode == ProgramScheduleMode.flexible;
    final pausedIds = state.pauses.where((p) => p.routineId != null && p.activeAt(now))
      .map((p) => p.routineId!).toSet();
    final mode = flexible ? 'Flexible' : active.scheduleMode == ProgramScheduleMode.fixed ? 'Fijo' : 'Continuo';
    final policy = active.scheduleMode == ProgramScheduleMode.fixed ? '' :
      active.repeatsWeekly ? ' · Repetición semanal' : ' · Rotación por sesiones';
    return SafeArea(top: false, child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
      child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(
        AppUiTokens.of(context).cardPadding, 0, AppUiTokens.of(context).cardPadding, AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(flexible ? 'Planificación flexible' : 'Planificación',
              style: AppTypography.headlineLarge)),
            IconButton(tooltip:'Cerrar planificación', onPressed:()=>Navigator.pop(context),
              icon:const Icon(Icons.close)),
          ]),
          Text('$mode$policy', style:AppTypography.bodySmall.copyWith(color:colors.textSecondary)),
          const SizedBox(height:AppSpacing.sm),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: AppSpacing.sm, runSpacing: AppSpacing.xxs, children:[
            Text('Semana ${active.weekAt(now)}',style:AppTypography.headlineSmall),
            Text('${plan.completed}/${plan.target} sesiones',style:AppTypography.bodyMedium),
          ]),
          const SizedBox(height:AppSpacing.xs),
          LinearProgressIndicator(key:const ValueKey('adaptive_week_progress'),
            value:plan.target==0?0:(plan.completed/plan.target).clamp(0.0,1.0).toDouble()),
          if (plan.isPaused) const Padding(padding:EdgeInsets.only(top:8),child:Text('Programa en pausa')),
          if (plan.goalReached) const Padding(padding:EdgeInsets.only(top:8),child:Text('Objetivo semanal cumplido')),
          if (_error != null) Padding(padding:const EdgeInsets.only(top:8),
            child:Text(_error!,style:TextStyle(color:colors.error))),
          const SizedBox(height:AppSpacing.sm),
          Text(flexible ? 'Orden de rotación' : 'Sesiones de la semana',style:AppTypography.headlineSmall),
          for (final (index,row) in rows.indexed) ...[
            Builder(builder:(context){
              final done = row.status == PlanOccurrenceStatus.completed;
              final omitted = row.status == PlanOccurrenceStatus.omitted;
              final paused = state.routinePausedAt(row.routineId,now);
              final next = row.id == plan.nextSuggestion?.occurrenceId;
              final reserved = state.bindings.containsValue(row.id);
              final date = row.notBefore ?? row.date;
              final missed = !flexible && active.scheduleMode == ProgramScheduleMode.fixed &&
                row.status == PlanOccurrenceStatus.pending && date != null && date.isBefore(ProgramAdaptationPolicy.day(now));
              final label = done?'Completada':omitted?'Omitida':paused?'Pausada':reserved?'En curso':
                missed?'Pendiente de recuperar':next?'Siguiente sesión':'Pendiente';
              return ListTile(key:ValueKey('adaptive_slot_${row.id}'),
                dense:true,contentPadding:EdgeInsets.zero,
                leading:done?Icon(Icons.check_circle_outline,color:colors.success):
                  paused?Icon(Icons.pause_circle_outline,color:colors.textSecondary):
                  omitted?const Icon(Icons.skip_next):next?Icon(Icons.radio_button_checked,color:colors.primary):
                  Text('${index+1}',style:AppTypography.labelMedium),
                title:Text(byId[row.routineId]?.name??'Rutina no disponible'),
                subtitle:Text([if (!flexible && date!=null) DateFormat('EEE d/M','es').format(date),
                  if (flexible && row.notBefore!=null) 'Pospuesta hasta ${DateFormat('d/M').format(row.notBefore!)}',
                  label].join(' · ')),
                trailing:done||reserved?null:IconButton(tooltip:'Adaptar sesión ${index+1}',
                  onPressed:_busy?null:()=>_slotActions(prepared,row,pending,byId,now),
                  icon:const Icon(Icons.more_horiz)));
            }),
            const Divider(height:1),
          ],
          if (rows.isEmpty) const Text('No hay sesiones previstas.'),
          if (!flexible && active.trainingWeekdays.isNotEmpty && active.scheduleMode == ProgramScheduleMode.continuous)
            Padding(padding:const EdgeInsets.only(top:8),child:Text('Días habituales: ${[for (var day = 1; day <= 7; day++) if (active.trainingWeekdays.contains(day)) const ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'][day-1]].join(' · ')}',
              style:AppTypography.bodySmall)),
          ExpansionTile(key:const ValueKey('adaptive_next_week'),tilePadding:EdgeInsets.zero,
            initiallyExpanded:_nextWeek,onExpansionChanged:(v)=>_nextWeek=v,
            title:const Text('Próxima semana'),subtitle:const Text('Estimación si completas las sesiones disponibles'),
            children:[for (final (i,id) in plan.nextWeekRoutineIds.indexed)
              ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Text('${i+1}'),
                title:Text(byId[id]?.name??'Rutina no disponible'))]),
          ExpansionTile(tilePadding:EdgeInsets.zero,initiallyExpanded:_showActions,
            onExpansionChanged:(v)=>_showActions=v,
            title:const Text('Adaptar planificación'),leading:const Icon(Icons.tune),
            children:[
              ListTile(contentPadding:EdgeInsets.zero,title:Text(plan.isPaused?'Reanudar programa':'Pausar programa'),
                onTap:_busy?null:() => plan.isPaused?
                  _apply('Reanudar programa','Se conservará tu progreso.',
                    (p,r,n)=>ProgramAdaptationPolicy.resume(p,n)):_pause(null)),
              ListTile(contentPadding:EdgeInsets.zero,title:const Text('Pausar rutinas'),
                onTap:_busy?null:()=>_pauseRoutines(routines.where((r)=>active.routineIds.contains(r.id)).toList())),
              if(pausedIds.isNotEmpty)
                ListTile(contentPadding:EdgeInsets.zero,title:const Text('Reanudar rutinas pausadas'),
                  subtitle:Text(pausedIds.map((id)=>byId[id]?.name??id).join(' · ')),
                  onTap:_busy?null:()=>_apply('Reanudar rutinas','Se volverán a incluir en el plan.',
                    (p,r,n)=>ProgramAdaptationPolicy.resume(p,n,routineIds:pausedIds))),
              if(past.isNotEmpty && pending.isNotEmpty)
                ListTile(contentPadding:EdgeInsets.zero,title:const Text('Recuperar sesión de otra semana'),
                  onTap:_busy?null:()async{
                    final old=await _choose('Sesión anterior',past,byId);
                    if(old==null||!mounted)return;
                    final replace=await _choose('Sustituir sesión pendiente',pending,byId);
                    if(replace==null||!mounted)return;
                    await _apply('Recuperar sesión anterior','La pendiente elegida quedará omitida, no completada.',
                      (p,r,n)=>ProgramAdaptationPolicy.recoverPrevious(p,r,old.id,replace.id,n));
                  }),
              const Text('Para entrenar sin cambiar el programa, inicia una rutina independiente desde Mis rutinas.'),
            ]),
          if(_busy) const LinearProgressIndicator(),
        ]))));
  }
}
