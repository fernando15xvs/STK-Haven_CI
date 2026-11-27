import 'dart:async';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/guided_habit_plan.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import '../data/private_journal_repository.dart';

class GuidedHabitPage extends ConsumerStatefulWidget {
  final GuidedHabitKind kind;
  const GuidedHabitPage({super.key,required this.kind});
  @override ConsumerState<GuidedHabitPage> createState()=>_GuidedHabitPageState();
}
class _GuidedHabitPageState extends ConsumerState<GuidedHabitPage> with WidgetsBindingObserver {
  final _note=TextEditingController();
  Timer? _ticker;
  late int _minutes;
  bool _busy=false;
  bool _saveNote=false;
  double? _before;
  double? _after;
  String? _action;
  HabitTaskTemplate get _template=>switch(widget.kind){
    GuidedHabitKind.night=>HabitTaskTemplates.windDown10Minutes,
    GuidedHabitKind.breathing=>HabitTaskTemplates.breathingPause,
    GuidedHabitKind.personalPause=>HabitTaskTemplates.recoveryPause,
  };
  String get _title=>switch(widget.kind){
    GuidedHabitKind.night=>'Rutina nocturna',GuidedHabitKind.breathing=>'Respiración guiada',
    GuidedHabitKind.personalPause=>'Pausa personal',
  };
  HabitTask? _task(Iterable<HabitTask> tasks)=>tasks.where((t)=>t.source!=HabitTaskSource.coach&&
    (t.sourceReference=='template:${_template.key}'||(t.sourceReference.isEmpty&&t.title==_template.title&&t.category==_template.category))).firstOrNull;
  @override void initState(){
    super.initState();_minutes=widget.kind==GuidedHabitKind.night?10:5;
    WidgetsBinding.instance.addObserver(this);
    _ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_ticker?.cancel();_note.dispose();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed){
      final task=_task(ref.read(habitTasksProvider).tasks);
      final timer=ref.read(habitStudyTimerProvider);
      if(task!=null&&timer?.taskId==task.id&&timer!.isRunning){unawaited(ref.read(habitStudyTimerProvider.notifier).pause());}
    }
  }
  void _error(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
  Future<void> _start()async{
    if(_busy)return;
    setState(()=>_busy=true);
    try{
      final current=ref.read(habitStudyTimerProvider);
      final task=_task(ref.read(habitTasksProvider).tasks);
      if(current!=null&&current.taskId!=task?.id){
        _error('Tienes otra sesión activa. Termínala o descártala desde Enfoque antes de iniciar esta.');return;
      }
      final resolved=task??await ref.read(habitTasksProvider.notifier).ensureTemplate(_template);
      if(current==null)await ref.read(habitStudyTimerProvider.notifier).start(taskId:resolved.id,targetMinutes:_minutes);
      else if(!current.isRunning)await ref.read(habitStudyTimerProvider.notifier).resume();
    }catch(_){_error('No se pudo iniciar la pausa.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _finish()async{
    if(_busy)return;
    final task=_task(ref.read(habitTasksProvider).tasks);
    final timer=ref.read(habitStudyTimerProvider);
    if(task==null||timer==null||timer.taskId!=task.id)return;
    setState(()=>_busy=true);
    try{
      final now=DateTime.now();
      final seconds=timer.elapsedSecondsAt(now).clamp(0,timer.targetSeconds).toInt();
      final id=timer.sessionId.isEmpty?'guided:${task.id}:${timer.updatedAt.toIso8601String()}':'guided:${timer.sessionId}';
      if(_saveNote){
        final text=[
          if(_before!=null)'Antes: ${_before!.round()}/10',
          if(_after!=null)'Después: ${_after!.round()}/10',
          if(_action!=null)'Siguiente acción: $_action',
          if(_note.text.trim().isNotEmpty)_note.text.trim(),
        ].join('\n');
        await PrivateJournalRepository().put(text,kind:_title,id:id);
      }
      await ref.read(habitTasksProvider.notifier).completeTask(taskId:task.id,minutesSpent:seconds~/60,
        completionId:id,status:seconds>0?HabitTaskCompletionStatus.completed:HabitTaskCompletionStatus.skipped);
      await ref.read(habitStudyTimerProvider.notifier).clear();
      if(mounted)Navigator.pop(context);
    }catch(_){_error('No se pudo guardar. Tu sesión sigue disponible.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  String _stageLabel(GuidedHabitStage stage)=>switch(stage){
    GuidedHabitStage.prepare=>'Preparar el entorno',GuidedHabitStage.breathe=>'Respirar a tu ritmo',
    GuidedHabitStage.reflect=>'Descarga mental opcional',GuidedHabitStage.close=>'Cerrar el día',
  };
  Widget _rating(String label,double? value,ValueChanged<double?> change)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label),if(value==null)TextButton(onPressed:()=>change(5),child:const Text('Registrar intensidad')),
    if(value!=null)...[
      Row(children:[Expanded(child:Slider(value:value,min:0,max:10,divisions:10,label:'${value.round()}',onChanged:change)),
        Text('${value.round()}/10'),IconButton(tooltip:'Quitar valoración',icon:const Icon(Icons.close),onPressed:()=>change(null))]),
    ],
  ]);
  @override Widget build(BuildContext context){
    final tasks=ref.watch(habitTasksProvider).tasks;
    final task=_task(tasks);
    final active=ref.watch(habitStudyTimerProvider);
    final timer=task!=null&&active?.taskId==task.id?active:null;
    final target=timer?.targetSeconds??_minutes*60;
    final elapsed=(timer?.elapsedSecondsAt(DateTime.now())??0).clamp(0,target).toInt();
    final remaining=target-elapsed;
    final stage=GuidedHabitPlan.stageAt(widget.kind,elapsed,target);
    final breathing=stage==GuidedHabitStage.breathe&&remaining>0;
    final inhale=(elapsed%10)<4;
    final moving=!MediaQuery.disableAnimationsOf(context)&&timer?.isRunning==true;
    final personal=widget.kind==GuidedHabitKind.personalPause;
    return Scaffold(appBar:AppBar(title:Text(_title)),body:ListView(
      padding:SecondaryScreenInsets.scrollPadding(context,const EdgeInsets.all(20)),children:[
        Text(personal?'Una pausa opcional para elegir tu siguiente acción.':'Una sesión a tu ritmo.',style:Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height:16),
        if(personal&&timer==null)_rating('¿Cómo te sientes al empezar?',_before,(v)=>setState(()=>_before=v)),
        if(timer==null)Wrap(spacing:8,children:[for(final m in widget.kind==GuidedHabitKind.night?[5,10,15]:[3,5,10])
          ChoiceChip(label:Text('$m min'),selected:_minutes==m,onSelected:(_)=>setState(()=>_minutes=m))]),
        PremiumCard(child:Column(children:[
          Text(remaining==0?'Sesión terminada':_stageLabel(stage),style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:16),
          if(breathing)SizedBox(height:180,child:Center(child:AnimatedContainer(
            duration:moving?const Duration(milliseconds:850):Duration.zero,
            width:moving?(inhale?158:112):140,height:moving?(inhale?158:112):140,
            decoration:BoxDecoration(shape:BoxShape.circle,color:Theme.of(context).colorScheme.primaryContainer),
            alignment:Alignment.center,child:Text(timer==null?'A tu ritmo':inhale?'Inhala · 4 s':'Exhala · 6 s',textAlign:TextAlign.center)))),
          Text('${(remaining~/60).toString().padLeft(2,'0')}:${(remaining%60).toString().padLeft(2,'0')}',style:Theme.of(context).textTheme.displaySmall),
          const SizedBox(height:12),LinearProgressIndicator(value:target==0?0:elapsed/target),
          const SizedBox(height:12),
          if(timer==null)FilledButton(onPressed:_busy?null:_start,child:const Text('Empezar')),
          if(timer!=null&&remaining>0)FilledButton.icon(onPressed:_busy?null:()async{
            if(timer.isRunning){await ref.read(habitStudyTimerProvider.notifier).pause();}else{await _start();}
          },icon:Icon(timer.isRunning?Icons.pause:Icons.play_arrow),label:Text(timer.isRunning?'Pausar':'Continuar')),
        ])),
        if(widget.kind==GuidedHabitKind.night)...[
          const SizedBox(height:16),for(final step in GuidedHabitPlan.steps(widget.kind,target))
            ListTile(contentPadding:EdgeInsets.zero,leading:Icon(step.stage==stage?Icons.radio_button_checked:Icons.circle_outlined),
              title:Text(_stageLabel(step.stage)),subtitle:Text('${step.seconds~/60} min')),
        ],
        if(personal&&timer!=null)...[
          const SizedBox(height:16),_rating('¿Cómo te sientes ahora?',_after,(v)=>setState(()=>_after=v)),
          const Text('Elige una acción si te ayuda'),
          Wrap(spacing:6,children:[for(final action in ['Alejar el teléfono','Hablar con alguien de confianza','Descansar en un lugar seguro','Tomar agua'])
            ChoiceChip(label:Text(action),selected:_action==action,onSelected:(v)=>setState(()=>_action=v?action:null))]),
        ],
        if(widget.kind!=GuidedHabitKind.breathing)...[
          const SizedBox(height:12),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Guardar una nota en el diario privado'),value:_saveNote,onChanged:(v)=>setState(()=>_saveNote=v)),
          if(_saveNote)TextField(controller:_note,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Nota opcional')),
        ],
        if(timer!=null)...[
          const SizedBox(height:16),FilledButton(onPressed:_busy?null:_finish,child:const Text('Finalizar y guardar')),
        ],
        if(personal)const Padding(padding:EdgeInsets.only(top:16),child:Text('No sustituye atención profesional. Si no puedes mantenerte a salvo o existe riesgo inmediato, busca ayuda de emergencia.')),
        if(widget.kind==GuidedHabitKind.breathing)const Padding(padding:EdgeInsets.only(top:16),child:Text('No fuerces la respiración. Puedes detenerte cuando lo necesites.')),
      ]));
  }
}
