import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/habits/presentation/study_habits_mobile_page.dart';

/// Today's checklist is a view of the existing habits store, never a second list.
class HomeHabitsCard extends ConsumerStatefulWidget {
  const HomeHabitsCard({super.key,required this.now});
  final DateTime now;
  @override
  ConsumerState<HomeHabitsCard> createState()=>_HomeHabitsCardState();
}
class _HomeHabitsCardState extends ConsumerState<HomeHabitsCard>{
  final _busy=<String>{};
  void _open()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const StudyHabitsMobilePage()));
  Future<void> _toggle(HabitTask task,bool value) async {
    if(!_busy.add(task.id))return;
    setState((){});
    try {await ref.read(habitTasksProvider.notifier).setHomeChecklist(task.id,value,DateTime.now());}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo actualizar el hábito.')));}
    finally{if(mounted)setState(()=>_busy.remove(task.id));}
  }
  @override
  Widget build(BuildContext context){
    final tasks=ref.watch(visibleHabitTasksProvider);
    final completions=ref.watch(habitTasksProvider.select((s)=>s.completions));
    final rows=tasks.where((t)=>HabitScheduleService.isDueOn(t,widget.now)).toList();
    bool done(HabitTask task)=>HabitScheduleService.isCompletedOn(task,completions,widget.now);
    final count=rows.where(done).length;
    final colors=AppColors.of(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:Text('MIS HÁBITOS',style:AppTypography.labelLarge.copyWith(color:colors.textSecondary))),
        if(rows.isNotEmpty)Text('$count/${rows.length}',style:AppTypography.labelMedium.copyWith(color:colors.primary)),
      ]),
      const SizedBox(height:AppSpacing.xs),
      PremiumCard(key:const ValueKey('home_habits_card'),
        padding:const EdgeInsets.symmetric(horizontal:AppSpacing.md,vertical:AppSpacing.xs),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(rows.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:12),
            child:Text('Sin hábitos previstos para hoy. Puedes crear los tuyos.')),
          for(final task in rows.take(3))
            if(task.type==HabitTaskType.checklist && task.targetMinutes==0 &&
                task.source!=HabitTaskSource.coach &&
                (!HabitScheduleService.isResolvedOn(task,completions,widget.now)||done(task)))
              CheckboxListTile(contentPadding:EdgeInsets.zero,
                key:ValueKey('home_habit_${task.id}'),title:Text(task.title),
                controlAffinity:ListTileControlAffinity.leading,value:done(task),
                onChanged:_busy.contains(task.id)?null:(v)=>_toggle(task,v??false))
            else
              ListTile(contentPadding:EdgeInsets.zero,leading:Icon(done(task)?Icons.check_circle_outline:Icons.schedule),
                title:Text(task.title),
                subtitle:Text(done(task)?'Completado':HabitScheduleService.isResolvedOn(task,completions,widget.now)
                  ?'Omitido': 'Abrir tarea'),trailing:const Icon(Icons.chevron_right),onTap:_open),
          if(rows.length>3)Text('+${rows.length-3} hábitos más',style:AppTypography.bodySmall),
          const Divider(height:1),
          TextButton(onPressed:_open,child:const Text('Gestionar hábitos')),
        ]),
      ),
    ]);
  }
}
