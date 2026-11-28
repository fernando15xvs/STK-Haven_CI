import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/adult_activity_suggestion.dart';
import 'package:core/features/nutrition/application/latest_body_measurements.dart';
import 'package:core/features/nutrition/application/nutrition_daily_context.dart';
import 'package:core/features/nutrition/application/nutrition_plan_measurement_review.dart';
import 'package:core/features/nutrition/application/nutrition_weight_trend.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/nutrition/data/nutrition_development_config.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/action_navigation_group.dart';
import 'nutrition_wellness_settings.dart';

class NutritionPlanOverview extends StatelessWidget {
  const NutritionPlanOverview({super.key,required this.plan,required this.goal,required this.onReview,required this.onMacros});
  final NutritionGoalPlan? plan;
  final EnergyGoal goal;
  final VoidCallback onReview;
  final ValueChanged<NutritionGoalPlan> onMacros;
  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    final plan=this.plan;
    final matches = plan?.goal == goal;
    final active = plan?.isPaused == false && matches;
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('nutrition_mobile_adult_plan'),
      color: colors.primaryContainer,
      child: Padding(
        padding: EdgeInsets.all(AppUiTokens.of(context).cardPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.local_fire_department_outlined, color: colors.onPrimaryContainer),
            const SizedBox(width:8),
            Expanded(child:Text('Plan energético',style:text.titleMedium?.copyWith(color:colors.onPrimaryContainer))),
          ]),
          const SizedBox(height:8),
          Text(plan != null && active ? '${plan.estimate.targetLow}–${plan.estimate.targetHigh} kcal/día'
            : plan == null ? 'Configura tu plan'
            : plan.isPaused ? 'Plan en pausa' : 'Nuevo objetivo por confirmar',
            style:text.headlineSmall?.copyWith(color:colors.onPrimaryContainer,fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text(plan != null && active ? 'Referencia guardada · ${DateFormat('dd/MM').format(plan.savedAt)}'
            : plan != null && !matches ? 'El plan anterior se conserva hasta que confirmes otro.'
            : 'Estimación orientativa, no prescripción.',
            style:text.bodySmall?.copyWith(color:colors.onPrimaryContainer)),
          if(NutritionDevelopmentConfig.enabled)
            Text('Acceso privado de pruebas',style:text.labelSmall?.copyWith(color:colors.onPrimaryContainer)),
          const SizedBox(height:8),
          FilledButton.icon(
            key: const ValueKey('nutrition_mobile_review_adult_plan'),
            onPressed: onReview,
            icon:const Icon(Icons.tune_rounded),
            label:Text(plan==null?'Calcular mi objetivo':'Revisar mi plan')),
          if(plan!=null && active && plan.ageYears>=19) ...[
            const Divider(),
            TextButton.icon(onPressed:()=>onMacros(plan),
              icon:const Icon(Icons.donut_small_outlined),label:const Text('Ver macronutrientes')),
          ],
        ]),
      ),
    );
  }
}

class NutritionWellnessOverview extends ConsumerWidget {
  const NutritionWellnessOverview({super.key,required this.intent,required this.adultAuthorized,required this.onHistory});
  final StkNutritionIntent intent;
  final bool adultAuthorized;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors=Theme.of(context).colorScheme;
    final water=ref.watch(hydrationPreferencesProvider);
    final steps=ref.watch(stepGoalPreferencesProvider);
    final now=DateTime.now();
    final sleep=ref.watch(sleepDiaryProvider);
    final recovery=ref.watch(recoveryProvider);
    final sessions=ref.watch(workoutHistoryProvider);
    final next=ref.watch(nextProgramSessionProvider);
    final completedMinutes=NutritionDailyContext.completedTrainingMinutes(sessions,now);
    final done=completedMinutes>0;
    final scheduled=next?.scheduledDate;
    final planned=scheduled!=null && SleepDiary.dayKey(scheduled.toLocal())==SleepDiary.dayKey(now);
    final advice=NutritionDailyContext.guidance(intent:intent,
      adultAuthorized:adultAuthorized,now:now,sleep:sleep,recovery:recovery,
      trainingCompleted:done,trainingPlanned:planned);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('Metas de bienestar',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      ActionNavigationGroup(children:[
        ActionNavigationTile(key:const ValueKey('nutrition_water_settings'),
          icon:Icons.water_drop_outlined,title:'Hidratación',
          subtitle:'${water.targetMl} ml/día · ${water.reminderEnabled?"Con avisos":"Sin avisos"}',
          onTap:()=>openNutritionWellnessSettings(context,water:true,adultAuthorized:adultAuthorized)),
        ActionNavigationTile(key:const ValueKey('nutrition_steps_settings'),
          icon:Icons.directions_walk_outlined,title:'Actividad diaria',
          subtitle:'${steps.targetSteps} pasos · ${steps.reminderEnabled?"Con avisos":"Sin avisos"}',
          onTap:()=>openNutritionWellnessSettings(context,water:false,adultAuthorized:adultAuthorized)),
        if(water.goalChanges.isNotEmpty || steps.goalChanges.isNotEmpty)
          ActionNavigationTile(icon:Icons.history_rounded,title:'Cambios de mis metas',
            onTap:onHistory),
      ]),
      const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Contexto de hoy',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:6),
          Text(done?'Entrenamiento registrado · $completedMinutes min':planned?'Entrenamiento previsto':'Sin sesión confirmada para hoy'),
          if(sleep.minutesFor(now) case final minutes?)
            Text('Sueño registrado: ${minutes~/60} h ${minutes%60} min'),
          if(recovery!=null && SleepDiary.dayKey(recovery.date)==SleepDiary.dayKey(now))
            Text('Recuperación: ${recovery.status.label}'),
          const SizedBox(height:6),
          Text(advice,style:Theme.of(context).textTheme.bodySmall?.copyWith(color:colors.onSurfaceVariant)),
        ],
      ))),
    ]);
  }
}

class NutritionFollowUp extends ConsumerWidget {
  const NutritionFollowUp({super.key,required this.plan,required this.previousCount,required this.onMeasurements,required this.onReview,required this.onPrevious});
  final NutritionGoalPlan? plan;
  final int previousCount;
  final VoidCallback? onMeasurements;
  final VoidCallback onReview,onPrevious;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records=ref.watch(bodyMeasurementProvider);
    final body=LatestBodyMeasurements.fromRecords(records);
    final trend=NutritionWeightTrend.fromRecords(records);
    final fortnight=NutritionDailyContext.weightReview(records,DateTime.now());
    final plan=this.plan;
    final review=plan==null?null:NutritionPlanMeasurementReview.compare(plan,body);
    final activity=AdultActivitySuggestionPolicy.suggest(recordedSteps:ref.read(wellnessRepositoryProvider).recentRecordedSteps(days:14),sessions:ref.watch(workoutHistoryProvider),now:DateTime.now());
    final activityChanged=plan!=null&&activity!=null&&plan.activityLevel!=activity.level;
    final nextReview=plan?.nextReviewAt;
    final due=nextReview!=null&&!nextReview.isAfter(DateTime.now());
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('Seguimiento',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      ActionNavigationGroup(children:[
        ActionNavigationTile(icon:Icons.monitor_weight_outlined,title:'Medidas',
          subtitle:body.weightKg==null?'Sin peso registrado':
            '${body.weightKg!.value.toStringAsFixed(1)} kg · ${DateFormat('dd/MM').format(body.weightKg!.recordedAt)}',
          onTap:onMeasurements),
        if(fortnight!=null) ActionNavigationTile(icon:Icons.show_chart_rounded,title:'Últimas dos semanas',
          subtitle:'${fortnight.earlier.toStringAsFixed(1)} → ${fortnight.recent.toStringAsFixed(1)} kg · medianas de ${fortnight.earlierDays} y ${fortnight.recentDays} días',
          onTap:onMeasurements)
        else if(trend!=null) ActionNavigationTile(icon:Icons.show_chart_rounded,
          title:'Cambio entre dos registros',
          subtitle:'${trend.differenceKg>=0?"+":""}${trend.differenceKg.toStringAsFixed(1)} kg · No es una tendencia por sí solo',
          onTap:onMeasurements),
        if(plan!=null) ActionNavigationTile(icon:Icons.event_outlined,title:'Revisar evolución',
          subtitle:review?.needsReview==true?'Medidas actualizadas · revisa el cálculo':
            due?'Fecha de revisión alcanzada':activityChanged?'La actividad registrada difiere de tu selección · revisar':'Sin ajustes automáticos',
          onTap:onReview),
        if(previousCount>0) ActionNavigationTile(icon:Icons.history_rounded,title:'Planes anteriores',
          subtitle:'$previousCount referencias guardadas',onTap:onPrevious),
      ]),
    ]);
  }
}
