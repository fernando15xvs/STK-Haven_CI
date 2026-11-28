import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/nutrition/application/hydration_context_guidance.dart';
import 'package:core/features/nutrition/application/wellness_goal_suggestions.dart';
import 'package:core/features/nutrition/application/latest_body_measurements.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/nutrition/application/nutrition_daily_context.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Both screens edit the same providers used by Home. No numeric nutrition
/// authorization is needed to manage ordinary wellbeing preferences.
Future<void> openNutritionWellnessSettings(BuildContext context,
    {required bool water, required bool adultAuthorized}) =>
  showModalBottomSheet<void>(context:context,isScrollControlled:true,
    useSafeArea:true,showDragHandle:true,
    builder:(_)=>_WellnessSettings(water:water,adultAuthorized:adultAuthorized));

class _WellnessSettings extends ConsumerStatefulWidget {
  const _WellnessSettings({required this.water,required this.adultAuthorized});
  final bool water, adultAuthorized;
  @override
  ConsumerState<_WellnessSettings> createState()=>_WellnessSettingsState();
}
class _WellnessSettingsState extends ConsumerState<_WellnessSettings> {
  late int target;
  late bool reminders;
  late int hour;
  late StepReminderCadence cadence;
  bool hot=false,sweat=false,prolonged=false,restricted=false,busy=false;
  String? error;

  @override
  void initState(){
    super.initState();
    final water=ref.read(hydrationPreferencesProvider);
    final steps=ref.read(stepGoalPreferencesProvider);
    target=widget.water?water.targetMl:steps.targetSteps;
    reminders=widget.water?water.reminderEnabled:steps.reminderEnabled;
    hour=water.reminderHour;
    cadence=steps.reminderCadence;
  }

  Future<void> _save() async {
    if(busy || (widget.water && restricted))return;
    setState((){busy=true;error=null;});
    try{
      bool granted;
      if(widget.water){
        await ref.read(hydrationPreferencesProvider.notifier).configure(
          targetMl:target,reminderEnabled:reminders,reminderHour:hour);
        if(!mounted)return;
        ref.read(hydrationProvider.notifier).checkDateAndRefresh();
        granted=await HydrationReminderService.syncNextReminder(
          enabled:reminders,currentMl:ref.read(hydrationProvider).waterMl,
          targetMl:target,reminderHour:hour,requestPermissionIfNeeded:reminders);
      }else{
        await ref.read(stepGoalPreferencesProvider.notifier).configure(
          targetSteps:target,reminderEnabled:reminders,cadence:cadence);
        if(!mounted)return;
        ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
        final steps=ref.read(dailyStepsProvider);
        granted=await StepGoalReminderService.syncToday(
          preferences:ref.read(stepGoalPreferencesProvider),currentSteps:steps.steps,
          lastSyncedAt:steps.lastSyncedAt,requestPermissionIfNeeded:reminders);
      }
      if(!mounted)return;
      if(reminders&&!granted){
        setState((){busy=false;error='Meta guardada. Revisa los permisos de notificaciones del dispositivo.';});
        return;
      }
      Navigator.pop(context);
    }catch(_){
      if(mounted)setState((){busy=false;error='No se pudo completar el guardado o los avisos. Revisa la meta actual.';});
    }
  }

  @override
  Widget build(BuildContext context){
    final colors=AppColors.of(context);
    final history=widget.water?null:ref.read(wellnessRepositoryProvider).recentRecordedSteps(days:14);
    final suggestion=history==null||!widget.adultAuthorized?null:
      WellnessGoalSuggestions.stepsFromBaseline(history.where((e)=>e.deviceSynced&&e.lastSyncedAt!=null).map((e)=>e.steps));
    final body=widget.water&&widget.adultAuthorized?
      LatestBodyMeasurements.fromRecords(ref.watch(bodyMeasurementProvider)):null;
    final completedMinutes=NutritionDailyContext.completedTrainingMinutes(ref.watch(workoutHistoryProvider),DateTime.now());
    final contextGuide=HydrationContextGuidance(prolongedActivity:prolonged,
      hotEnvironment:hot,heavySweating:sweat,fluidRestriction:restricted);
    return PopScope(canPop:!busy,child:SafeArea(top:false,child:SingleChildScrollView(
      padding:EdgeInsets.fromLTRB(20,0,20,20+MediaQuery.viewInsetsOf(context).bottom),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
        Text(widget.water?'Hidratación':'Actividad diaria',style:AppTypography.headlineLarge),
        const SizedBox(height:AppSpacing.sm),
        Text(widget.water?'Meta personal de agua':'Meta personal de pasos',style:AppTypography.bodySmall),
        Text(widget.water?'$target ml/día':'$target pasos/día',style:AppTypography.headlineLarge),
        Slider(value:target.toDouble(),min:1000,max:widget.water?5000:50000,
          divisions:widget.water?16:98,onChanged:busy||restricted?null:(v)=>setState(()=>target=v.round())),
        if(widget.water)...[
          if(body?.weightKg case final weight?) Text('Peso de Medidas: ${weight.value.toStringAsFixed(1)} kg · contexto, no fórmula de agua.'),
          if(completedMinutes>0) Text('Entrenamiento registrado hoy: $completedMinutes min. Revisa calor y sudoración.'),
          const SizedBox(height:AppSpacing.sm),
          Text('Contexto de hidratación',style:AppTypography.headlineSmall),
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Actividad prolongada'),value:prolonged,onChanged:busy?null:(v)=>setState(()=>prolonged=v??false)),
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Ambiente caluroso'),value:hot,onChanged:busy?null:(v)=>setState(()=>hot=v??false)),
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Sudoración elevada'),value:sweat,onChanged:busy?null:(v)=>setState(()=>sweat=v??false)),
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Tengo indicación médica de limitar líquidos'),value:restricted,onChanged:busy?null:(v)=>setState(()=>restricted=v??false)),
          Text(contextGuide.guidance,style:AppTypography.bodySmall),
        ]else...[
          const Text('La meta es una referencia personal, no una obligación ni una forma de compensar comida.'),
          if(suggestion!=null) TextButton.icon(onPressed:busy?null:()=>setState(()=>target=suggestion),
            icon:const Icon(Icons.insights_outlined),label:Text('Revisar referencia: $suggestion pasos')),
          if(suggestion==null && widget.adultAuthorized)const Text('Sin suficientes días válidos del sensor para una referencia.'),
        ],
        const Divider(),
        SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:const Text('Recordatorios'),
          value:reminders,onChanged:busy?null:(v)=>setState(()=>reminders=v)),
        if(reminders && widget.water) DropdownButtonFormField<int>(
          initialValue:hour,decoration:const InputDecoration(labelText:'Horario'),
          items:[for(var h=6;h<=22;h++)DropdownMenuItem(value:h,child:Text('${h.toString().padLeft(2,'0')}:00'))],
          onChanged:busy?null:(v)=>setState(()=>hour=v??hour)),
        if(reminders && !widget.water) DropdownButtonFormField<StepReminderCadence>(
          initialValue:cadence,decoration:const InputDecoration(labelText:'Frecuencia'),
          items:const [
            DropdownMenuItem(value:StepReminderCadence.gentle,child:Text('Suave · 20:00')),
            DropdownMenuItem(value:StepReminderCadence.balanced,child:Text('17:30 y 20:30')),
          ],onChanged:busy?null:(v)=>setState(()=>cadence=v??cadence)),
        const SizedBox(height:AppSpacing.md),
        if(error!=null)Text(error!,style:TextStyle(color:colors.error)),
        if(busy)const LinearProgressIndicator(),
        FilledButton(onPressed:busy||(widget.water&&restricted)?null:_save,child:const Text('Guardar configuración')),
      ]),
    )));
  }
}
