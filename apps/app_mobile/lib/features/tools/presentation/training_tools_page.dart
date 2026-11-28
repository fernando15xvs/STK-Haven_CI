import 'dart:async';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/tools/application/training_tools.dart';
import 'package:core/features/tools/application/training_timer.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/action_navigation_group.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/barbell_calculator_modal.dart';

Future<void> _toolSheet(BuildContext context,Widget child) =>
    showModalBottomSheet<void>(context:context,useSafeArea:true,isScrollControlled:true,
      showDragHandle:true,builder:(ctx)=>Padding(
        padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),
        child:ConstrainedBox(constraints:BoxConstraints(
          maxHeight:(MediaQuery.sizeOf(ctx).height-MediaQuery.viewInsetsOf(ctx).bottom)*0.85),
          child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,0,16,24),child:child))));

class TrainingToolsPage extends StatelessWidget {
  const TrainingToolsPage({super.key});
  static Future<void> show(BuildContext context)=>_toolSheet(context,const TrainingToolsPage());
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const _ToolHeading('Herramientas'),
      ActionNavigationGroup(children:[
        ActionNavigationTile(icon:Icons.calculate_outlined,title:'Calculadora 1RM',
          subtitle:'Fuerza estimada e intensidad',onTap:()=>OneRmTool.show(context)),
        ActionNavigationTile(icon:Icons.fitness_center,title:'Calculadora de discos',
          subtitle:'Configura la carga de tu barra',onTap:()=>BarbellCalculatorModal.show(context)),
        ActionNavigationTile(icon:Icons.timer_outlined,title:'Temporizador',
          subtitle:'Cuenta regresiva y cronómetro',onTap:()=>TrainingTimerTool.show(context)),
      ]),
    ]);
}
class _ToolHeading extends StatelessWidget {
  const _ToolHeading(this.title);
  final String title;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Text(title,style:AppTypography.headlineMedium)),
    IconButton(tooltip:'Cerrar',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
  ]);
}

class OneRmTool extends ConsumerStatefulWidget {
  const OneRmTool({super.key,this.exerciseId,this.weightKg,this.reps});
  final String? exerciseId;
  final double? weightKg;
  final int? reps;
  static Future<void> show(BuildContext context,{String? exerciseId,double? weightKg,int? reps})=>
      _toolSheet(context,OneRmTool(exerciseId:exerciseId,weightKg:weightKg,reps:reps));
  @override ConsumerState<OneRmTool> createState()=>_OneRmToolState();
}
class _OneRmToolState extends ConsumerState<OneRmTool> {
  final _weight=TextEditingController();
  final _reps=TextEditingController();
  String? _exerciseId;
  String? _reference;
  late final WeightUnit _unit;
  @override void initState(){
    super.initState();
    _unit=ref.read(settingsProvider).weightUnit;
    _exerciseId=widget.exerciseId;
    if(widget.weightKg!=null && widget.reps!=null){
      _weight.text=WeightConverter.displayWeight(widget.weightKg!,_unit).toStringAsFixed(3);
      _reps.text='${widget.reps}';
      _reference='Serie de referencia · editable';
    }else if(_exerciseId!=null){
      _loadHistory(_exerciseId);
    }
  }
  void _loadHistory(String? id){
    _exerciseId=id;
    _weight.clear();_reps.clear();_reference=null;
    if(id==null)return;
    final memory=ExercisePerformanceMemory.latestForExercise(ref.read(workoutHistoryProvider),id);
    final set=memory?.latestRepresentativeSet;
    if(set==null)return;
    _weight.text=WeightConverter.displayWeight(set.performanceWeight,_unit).toStringAsFixed(3);
    _reps.text='${set.performanceReps}';
    _reference='Última serie completada · editable';
  }
  @override void dispose(){_weight.dispose();_reps.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final exercises=ref.watch(exerciseListProvider);
    final supported=exercises.where((e)=>ExerciseToolAdvisor.forExercise(e).primary.contains(TrainingToolKind.oneRm)).toList();
    final unit=_unit;
    final typed=double.tryParse(_weight.text.replaceAll(',','.'))??0;
    final result=OneRmCalculator.estimate(weight:WeightConverter.toCanonicalKg(typed,unit),reps:int.tryParse(_reps.text)??0);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const _ToolHeading('Calculadora 1RM'),
      DropdownButtonFormField<String>(
        key:ValueKey(_exerciseId),initialValue:supported.any((e)=>e.id==_exerciseId)?_exerciseId:'',
        isExpanded:true,decoration:const InputDecoration(labelText:'Ejercicio (opcional)'),
        items:[const DropdownMenuItem(value:'',child:Text('Cálculo manual')),
          for(final Exercise e in supported) DropdownMenuItem(value:e.id,child:Text(e.name,overflow:TextOverflow.ellipsis))],
        onChanged:(value)=>setState(()=>_loadHistory(value==null||value.isEmpty?null:value))),
      if(_reference!=null) Text(_reference!,style:AppTypography.bodySmall),
      const SizedBox(height:12),
      TextField(controller:_weight,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:InputDecoration(labelText:'Peso (${unit.label})'),
        onChanged:(_)=>setState(()=>_reference=null)),
      const SizedBox(height:8),
      TextField(controller:_reps,keyboardType:TextInputType.number,
        decoration:const InputDecoration(labelText:'Repeticiones (1–10)'),
        onChanged:(_)=>setState(()=>_reference=null)),
      const SizedBox(height:16),
      if(result>0 && result.isFinite)...[
        Text('1RM estimado',style:AppTypography.bodyMedium),
        Text(WeightConverter.formatWeight(result,unit),style:AppTypography.headlineLarge),
        const SizedBox(height:10),
        for(final entry in OneRmCalculator.percentageTable(result).entries)
          Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[
            Expanded(child:Text('${entry.key}%')),
            Text(WeightConverter.formatWeight(entry.value,unit)),
          ])),
      ]else const Text('Introduce un peso positivo y entre 1 y 10 repeticiones.'),
      const SizedBox(height:8),
      const Text('Referencia aproximada. No cambia series, récords ni objetivos de carga.'),
    ]);
  }
}

class TrainingTimerTool extends ConsumerStatefulWidget {
  const TrainingTimerTool({super.key});
  static Future<void> show(BuildContext context)=>_toolSheet(context,const TrainingTimerTool());
  @override ConsumerState<TrainingTimerTool> createState()=>_TrainingTimerToolState();
}
class _TrainingTimerToolState extends ConsumerState<TrainingTimerTool> with WidgetsBindingObserver {
  Timer? _repaint;
  final _custom=TextEditingController();
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repaint=Timer.periodic(const Duration(milliseconds:250),(_){if(mounted && ref.read(trainingTimerProvider).running)setState((){});});
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){ref.read(trainingTimerProvider.notifier).refresh();if(mounted)setState((){});}
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_repaint?.cancel();_custom.dispose();super.dispose();}
  String _format(int value)=>'${(value~/60).toString().padLeft(2,'0')}:${(value%60).toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context){
    final timer=ref.watch(trainingTimerProvider);
    final controller=ref.read(trainingTimerProvider.notifier);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const _ToolHeading('Temporizador'),
      Wrap(spacing:8,children:[
        ChoiceChip(label:const Text('Cuenta regresiva'),selected:!timer.stopwatch,onSelected:timer.running?null:(_)=>controller.configure(timer.duration)),
        ChoiceChip(label:const Text('Cronómetro'),selected:timer.stopwatch,onSelected:timer.running?null:(_)=>controller.configure(timer.duration,stopwatch:true)),
      ]),
      const SizedBox(height:16),
      Text(_format(timer.displayAt(DateTime.now())),textAlign:TextAlign.center,style:AppTypography.displayMedium),
      if(!timer.stopwatch)...[
        if(timer.completeAt(DateTime.now()))const Center(child:Text('Intervalo finalizado')),
        Wrap(spacing:8,children:[
          for(final seconds in [30,60,90,120,180])
            ChoiceChip(label:Text('${seconds}s'),selected:timer.duration==seconds,
              onSelected:timer.running?null:(_)=>controller.configure(seconds)),
        ]),
        TextField(controller:_custom,enabled:!timer.running,keyboardType:TextInputType.number,
          decoration:InputDecoration(labelText:'Duración en segundos (1–86400)',
            suffixIcon:IconButton(tooltip:'Aplicar duración',onPressed:timer.running?null:(){
              final seconds=int.tryParse(_custom.text);
              if(seconds!=null && seconds>=1 && seconds<=86400){controller.configure(seconds);}
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Introduce entre 1 y 86400 segundos.')));
            },icon:const Icon(Icons.check)))),
      ],
      const SizedBox(height:12),
      FilledButton.icon(onPressed:timer.running?controller.pause:controller.start,
        icon:Icon(timer.running?Icons.pause:Icons.play_arrow),label:Text(timer.running?'Pausar':'Iniciar')),
      OutlinedButton(onPressed:controller.reset,child:const Text('Reiniciar')),
      const Text('Independiente del descanso de entrenamiento. El tiempo sigue al cerrar esta hoja; los avisos requieren permiso del dispositivo.'),
    ]);
  }
}
