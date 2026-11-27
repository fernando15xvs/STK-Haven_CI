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
import 'package:gym_tracker/core/theme/components/action_navigation_group.dart';
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
  bool _forecastNoMore = false;
  bool _showActions = false;
  String? _error;

  Future<bool> _confirm(String title, String message) async =>
    await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
      ])) == true;

  Future<void> _apply(String title, String description, _PlanCommand command) async {
    final expected = ref.read(activeTrainingProgramProvider)?.id;
    if (_busy || !await _confirm(title, description) || !mounted || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(trainingProgramListProvider.notifier).adaptActive((p,r,n) {
        if (p.id != expected) throw StateError('El programa activo cambió.');
        return command(p,r,n);
      });
      if (mounted && _showActions) setState(() => _showActions = false);
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

  Future<void> _editAvailability(TrainingProgram prepared, DateTime now) async {
    final today = ProgramAdaptationPolicy.day(now);
    final end = TrainingProgram.shiftCalendarDays(prepared.adaptation!.week,7);
    final selected = prepared.adaptation!.unavailableDays.where((d)=>!d.isBefore(today)).toSet();
    final days = <DateTime>[];
    for (var d=today; d.isBefore(end); d=TrainingProgram.shiftCalendarDays(d,1)) {
      days.add(d);
    }
    final result = await showDialog<Set<DateTime>>(context:context,builder:(ctx)=>
      StatefulBuilder(builder:(ctx,change)=>AlertDialog(
        title:const Text('Disponibilidad de esta semana'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Marca los días en que no podrás entrenar. No se omiten sesiones ni cambia tu objetivo habitual.'),
          for(final d in days) CheckboxListTile(value:selected.contains(d),
            title:Text(DateFormat('EEE d/M','es').format(d)),
            onChanged:(v)=>change((){if(v==true){selected.add(d);}else{selected.remove(d);}})),
        ])),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,selected),child:const Text('Continuar')),
        ])));
    if (result==null||!mounted) return;
    await _apply('Guardar disponibilidad','El cambio solo aplica esta semana. Las sesiones pendientes no se marcarán como completadas.',
      (p,r,n)=>ProgramAdaptationPolicy.setUnavailableDays(p,r,n,result));
  }

  Future<void> _repairRotation(TrainingProgram prepared, List<Routine> routines,
      Map<String,Routine> byId, DateTime now) async {
    final selected = await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(
      title:const Text('¿Qué rutina debe seguir?'),children:[
        const Padding(padding:EdgeInsets.all(16),child:Text('Elige la próxima rutina del orden base. Solo se reconstruirán las sesiones pendientes; se conservarán las completadas y omitidas.')),
        for(final id in prepared.routineIds)
          SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,id),child:Text(byId[id]?.name??'Rutina no disponible')),
      ]));
    if(selected==null||!mounted) return;
    try {
      final preview=ProgramAdaptationPolicy.repairRolling(prepared,routines,now,selected);
      final names=ProgramAdaptationPolicy.current(preview)
        .where((o)=>o.status==PlanOccurrenceStatus.pending)
        .map((o)=>byId[o.routineId]?.name??'Rutina').join(' → ');
      await _apply('Reparar orden pendiente',
        'Nuevo orden: $names. Se reemplazarán intercambios y posposiciones pendientes. Las pausas, ausencias, omisiones e historial se conservan.',
        (p,r,n)=>ProgramAdaptationPolicy.repairRolling(p,r,n,selected));
    } catch (_) {
      if(mounted) setState(()=>_error='Finaliza o descarta la sesión en curso antes de reparar el orden.');
    }
  }

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
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'tomorrow'), child: const Text('Hasta mañana')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx,'week'), child: const Text('Hasta el próximo lunes')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'manual'),
          child: const Text('Hasta que decida reanudar')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'date'),
          child: const Text('Hasta una fecha')),
      ]));
    if (choice == null || !mounted) return;
    DateTime? until;
    final today = ProgramAdaptationPolicy.day(DateTime.now());
    if (choice == 'tomorrow') until = TrainingProgram.shiftCalendarDays(today,1);
    if (choice == 'week') until = TrainingProgram.shiftCalendarDays(TrainingProgram.localWeekStart(today),7);
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
    final projectedDates = {for (final slot in plan.slots) slot.id: slot.date};
    final nextMonday=TrainingProgram.shiftCalendarDays(state.week,7);
    final noMore=ProgramAdaptationPolicy.current(ProgramAdaptationPolicy.prepare(prepared,routines,nextMonday)).map((o)=>o.routineId).toList();
    final forecastIds=_forecastNoMore?noMore:plan.nextWeekRoutineIds;
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
    final canRepair = !active.repeatsWeekly &&
        active.scheduleMode != ProgramScheduleMode.fixed && pending.isNotEmpty;
    final canReview = rows.any((o) => o.status == PlanOccurrenceStatus.pending &&
        state.bindings.containsValue(o.id));
    if (_showActions) {
      return PopScope<PlanningStart>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_busy) setState(() { _showActions = false; _error = null; });
        },
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppUiTokens.of(context).cardPadding),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Volver a planificación',
                    onPressed: _busy ? null : () => setState(() {
                      _showActions = false; _error = null;
                    }),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(child: Text('Adaptar planificación',
                    style: AppTypography.headlineMedium)),
                ]),
              ),
              if (_busy) const LinearProgressIndicator(),
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('adaptive_actions_scroll'),
                  padding: EdgeInsets.fromLTRB(
                    AppUiTokens.of(context).cardPadding, AppSpacing.sm,
                    AppUiTokens.of(context).cardPadding, AppSpacing.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_error != null) Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(_error!, style: AppTypography.bodyMedium.copyWith(color: colors.error)),
                    ),
                    const ActionSectionHeading('Disponibilidad'),
                    ActionNavigationGroup(children: [
                      ActionNavigationTile(icon: Icons.event_busy_outlined, title: 'No puedo entrenar hoy',
                        subtitle: 'Conservar las sesiones; no es una omisión',
                        onTap:_busy?null:()=>_apply('Descansar hoy','La sesión quedará pendiente. En modo fijo podrás recuperarla explícitamente.',
                          (p,r,n)=>ProgramAdaptationPolicy.setUnavailableDays(p,r,n,{
                    ...ProgramAdaptationPolicy.prepare(p,r,n).adaptation!.unavailableDays.where((d)=>!d.isBefore(ProgramAdaptationPolicy.day(n))),
                    ProgramAdaptationPolicy.day(n)}))),
                      ActionNavigationTile(icon: Icons.calendar_month_outlined, title: 'Tengo menos días disponibles',
                        subtitle: 'Solo esta semana',onTap:_busy?null:()=>_editAvailability(prepared,now)),
                    ]),
                    if (pending.length > 1 || canRepair || canReview) ...[
                      const SizedBox(height: AppSpacing.md),
                      const ActionSectionHeading('Orden de entrenamiento'),
                      ActionNavigationGroup(children: [
                      if(pending.length>1)
                        ActionNavigationTile(icon: Icons.swap_horiz_rounded, title: 'Cambiar mi próximo entrenamiento',
                          subtitle: 'Intercambiar dos sesiones sin cambiar el programa',
                          onTap:_busy?null:()async{
                    final first=await _choose('Sesión que quieres cambiar',pending,byId);
                    if(first==null||!mounted)return;
                    final second=await _choose('Entrenar en su lugar',pending.where((o)=>o.id!=first.id).toList(),byId);
                    if(second==null||!mounted)return;
                    await _apply('Intercambiar sesiones','Ambas seguirán en el programa, con el orden intercambiado.',
                      (p,r,n)=>ProgramAdaptationPolicy.exchange(p,r,first.id,second.id,n));
                          }),
                      if (canRepair)
                        ActionNavigationTile(icon: Icons.reorder_rounded, title: 'Reparar orden de rotación',
                          subtitle: 'Reconstruir solo las sesiones pendientes',onTap:_busy?null:()=>_repairRotation(prepared,routines,byId,now)),
                      if (canReview)
                        ActionNavigationTile(icon: Icons.fact_check_outlined, title: 'Revisar sesión en curso',
                          subtitle: 'Liberar únicamente reservas sin entrenamiento guardado',
                          onTap:_busy?null:()async{
                    if(!await _confirm('Revisar reservas','Se conservará cualquier entrenamiento activo o guardado.')||!mounted)return;
                    if (_busy) return;
                    setState(() { _busy = true; _error = null; });
                    try {
                      await ref.read(trainingProgramListProvider.notifier).recoverAbandonedReservations();
                      if (mounted) setState(() => _showActions = false);
                    } catch (_) {
                      if (mounted) setState(() => _error = 'No se pudo revisar las reservas.');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                          }),
                      ]),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const ActionSectionHeading('Pausas y recuperación'),
                    ActionNavigationGroup(children: [
                      ActionNavigationTile(
                        icon: plan.isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                        title: plan.isPaused ? 'Reanudar programa' : 'Pausar programa',
                        subtitle: plan.isPaused ? 'Continuar con las sesiones pendientes' : 'Suspender temporalmente',
                        onTap:_busy?null:() => plan.isPaused?
                          _apply('Reanudar programa','Se conservará tu progreso.',
                    (p,r,n)=>ProgramAdaptationPolicy.resume(p,n)):_pause(null)),
                      ActionNavigationTile(icon: Icons.healing_outlined, title: 'Lesión o molestia física',
                        subtitle: 'Pausar temporalmente rutinas afectadas',
                        onTap:_busy?null:()=>_pauseRoutines(routines.where((r)=>active.routineIds.contains(r.id)).toList())),
                      if(pausedIds.isNotEmpty)
                        ActionNavigationTile(icon: Icons.play_circle_outline, title: 'Reanudar rutinas pausadas',
                          subtitle:pausedIds.map((id)=>byId[id]?.name??id).join(' · '),
                          onTap:_busy?null:()=>_apply('Reanudar rutinas','Se volverán a incluir en el plan.',
                    (p,r,n)=>ProgramAdaptationPolicy.resume(p,n,routineIds:pausedIds))),
                      if(past.isNotEmpty && pending.isNotEmpty)
                        ActionNavigationTile(icon: Icons.history_rounded, title: 'Recuperar sesión de otra semana',
                          subtitle: 'Elegir una sesión anterior pendiente de recuperar',
                          onTap:_busy?null:()async{
                    final old=await _choose('Sesión anterior',past,byId);
                    if(old==null||!mounted)return;
                    final replace=await _choose('Sustituir sesión pendiente',pending,byId);
                    if(replace==null||!mounted)return;
                    await _apply('Recuperar sesión anterior','La pendiente elegida quedará omitida, no completada.',
                      (p,r,n)=>ProgramAdaptationPolicy.recoverPrevious(p,r,old.id,replace.id,n));
                          }),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.shield_outlined, color: colors.primary, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text('Tu historial de entrenamiento se conserva.',
                        style: AppTypography.bodySmall.copyWith(color: colors.textSecondary))),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Para entrenar sin cambiar el programa, inicia una rutina independiente desde Mis rutinas.',
                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
    }
    return SafeArea(top: false, child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
      child: SingleChildScrollView(
        key: const ValueKey('adaptive_calendar_scroll'),
        padding: EdgeInsets.fromLTRB(
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
          if (plan.closedBelowGoal) Padding(padding:const EdgeInsets.only(top:8),child:Text('Planificación cerrada · ${plan.completed} de ${plan.target} sesiones realizadas')),
          if (state.unavailableDays.any((d)=>!d.isBefore(ProgramAdaptationPolicy.day(now))))
            const Padding(padding:EdgeInsets.only(top:8),child:Text('Disponibilidad temporal ajustada esta semana')),
          if (_error != null) Padding(padding:const EdgeInsets.only(top:8),
            child:Text(_error!,style:TextStyle(color:colors.error))),
          const SizedBox(height:AppSpacing.md),
          FilledButton(
            key: const ValueKey('adaptive_open_actions'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            ),
            onPressed: _busy ? null : () => setState(() { _showActions = true; _error = null; }),
            child: const Row(children: [
              Icon(Icons.tune_rounded),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Adaptar planificación')),
              Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height:AppSpacing.md),
          Text(flexible ? 'Orden de rotación' : 'Sesiones de la semana',style:AppTypography.headlineSmall),
          const SizedBox(height:AppSpacing.xs),
          if (rows.isNotEmpty)
            ActionNavigationGroup(children: [
          for (final (index,row) in rows.indexed)
            Builder(builder:(context){
              final done = row.status == PlanOccurrenceStatus.completed;
              final omitted = row.status == PlanOccurrenceStatus.omitted;
              final paused = state.routinePausedAt(row.routineId,now);
              final next = row.id == plan.nextSuggestion?.occurrenceId;
              final reserved = state.bindings.containsValue(row.id);
              final date = flexible ? row.notBefore : projectedDates[row.id];
              final missed = !flexible && active.scheduleMode == ProgramScheduleMode.fixed &&
                row.status == PlanOccurrenceStatus.pending && date != null && date.isBefore(ProgramAdaptationPolicy.day(now));
              final label = done?'Completada':omitted?'Omitida':paused?'Pausada':reserved?'En curso':
                missed?'Pendiente de recuperar':row.notBefore!=null&&row.notBefore!.isAfter(ProgramAdaptationPolicy.day(now))?'Pospuesta':
                next?'Siguiente sesión':!flexible&&date==null&&active.scheduleMode==ProgramScheduleMode.continuous?'Pendiente · sin día disponible':'Pendiente';
              return ListTile(key:ValueKey('adaptive_slot_${row.id}'),
                dense:true,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                titleTextStyle: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                subtitleTextStyle: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                leading:done?Icon(Icons.check_circle_outline,color:colors.success):
                  paused?Icon(Icons.pause_circle_outline,color:colors.textSecondary):
                  omitted?const Icon(Icons.skip_next):next?Icon(Icons.radio_button_checked,color:colors.primary):
                  Text('${index+1}',style:AppTypography.labelMedium),
                title:Text(byId[row.routineId]?.name??'Rutina no disponible'),
                subtitle:Text([if (!flexible && date!=null) DateFormat('EEE d/M','es').format(date),
                  if (row.notBefore!=null && (flexible||date==null)) 'Pospuesta hasta ${DateFormat('d/M').format(row.notBefore!)}',
                  label].join(' · ')),
                trailing:done||reserved?null:IconButton(tooltip:'Adaptar sesión ${index+1}',
                  onPressed:_busy?null:()=>_slotActions(prepared,row,pending,byId,now),
                  icon:const Icon(Icons.more_horiz)));
            }),
          ]),
          if (rows.isEmpty) const Text('No hay sesiones previstas.'),
          if (!flexible && active.trainingWeekdays.isNotEmpty &&
              active.scheduleMode == ProgramScheduleMode.continuous) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Días habituales', style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              for (var day = 1; day <= 7; day++)
                Semantics(
                  label: const ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'][day - 1],
                  selected: active.trainingWeekdays.contains(day),
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: active.trainingWeekdays.contains(day)
                          ? colors.primaryFaded : colors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppUiTokens.of(context).buttonRadius),
                    ),
                    child: Text(
                      const ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'][day - 1],
                      style: AppTypography.bodySmall.copyWith(
                        color: active.trainingWeekdays.contains(day)
                            ? colors.primary : colors.textSecondary),
                    ),
                  ),
                ),
            ]),
          ],
          const SizedBox(height:AppSpacing.md),
          ActionNavigationGroup(children: [
          ExpansionTile(key:const ValueKey('adaptive_next_week'),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            childrenPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            initiallyExpanded:_nextWeek,onExpansionChanged:(v)=>_nextWeek=v,
            leading: Icon(Icons.date_range_outlined, color: colors.primary),
            title:const Text('Próxima semana'),subtitle:const Text('Estimación según lo que entrenes esta semana'),
            children:[
              SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Si no entreno más esta semana'),
                subtitle:const Text('Desactiva para estimar las sesiones disponibles'),value:_forecastNoMore,
                onChanged:(v)=>setState(()=>_forecastNoMore=v)),
              for (final (i,id) in forecastIds.indexed)
              ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Text('${i+1}'),
                title:Text(byId[id]?.name??'Rutina no disponible'))]),
          ]),
          if(_busy) const LinearProgressIndicator(),
        ]))));
  }
}
