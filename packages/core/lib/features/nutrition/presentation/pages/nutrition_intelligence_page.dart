import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:core/features/nutrition/application/adult_energy_planner.dart';
import 'package:core/features/nutrition/application/adult_macro_guide.dart';
import 'package:core/features/nutrition/application/latest_body_measurements.dart';
import 'package:core/features/nutrition/application/nutrition_weight_trend.dart';
import 'package:core/features/nutrition/application/nutrition_plan_measurement_review.dart';
import 'package:core/features/nutrition/application/nutrition_access_state.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/nutrition/application/wellness_goal_suggestions.dart';
import 'package:core/domain/models/wellness_goal_change.dart';
import 'package:core/features/nutrition/application/food_vision_correction.dart';
import 'package:core/features/nutrition/data/food_vision_service.dart';
import 'package:core/features/nutrition/data/nutrition_history_repository.dart';
import 'package:core/features/nutrition/data/nutrition_goal_plan_repository.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NutritionPhotoSource { camera, gallery }

typedef NutritionPhotoPicker = Future<NutritionPhoto?> Function(
  NutritionPhotoSource source,
);

class NutritionIntelligencePage extends ConsumerStatefulWidget {
  final NutritionPhotoPicker photoPicker;
  final bool cameraAvailable;
  final bool verifiedAdultNutritionAccess;
  final VoidCallback? onOpenMeasurements;
  final VoidCallback? onRefreshAdultAccess;

  const NutritionIntelligencePage({
    super.key,
    required this.photoPicker,
    this.cameraAvailable = true,
    this.verifiedAdultNutritionAccess = false,
    this.onOpenMeasurements,
    this.onRefreshAdultAccess,
  });

  @override
  ConsumerState<NutritionIntelligencePage> createState() =>
      _NutritionIntelligencePageState();
}

class _NutritionIntelligencePageState
    extends ConsumerState<NutritionIntelligencePage> {
  // No demographic or measurement values are ever fabricated as defaults.
  final _ageController = TextEditingController();
  final _energyFormKey=GlobalKey();
  final _foodFormKey=GlobalKey();
  final _dishHintController = TextEditingController();

  EnergyEquationSex? _equationSex;
  // No fabricated activity level: the user must confirm everyday activity.
  EnergyActivityLevel? _activity;
  EnergyGoal _goal = EnergyGoal.maintenance;
  EnergyEstimate? _energyEstimate;
  String? _calculationMeasurementIds;
  AdultEnergyProfile? _calculatedProfile;
  LatestBodyMeasurements? _calculatedBody;
  NutritionGoalPlan? _activePlan;
  NutritionGoalPlanRepository? _planRepository;

  // Even when backend authorization is true, a locally declared minor is
  // shown the safer descriptive Food Vision experience. A local birthday
  // can NEVER grant the remote numeric authorization by itself.
  bool get _hasAdultNumericAccess => ref.read(
    nutritionAccessStateProvider(widget.verifiedAdultNutritionAccess),
  ).canViewNumericNutrition;

  /// Draft values belong to the exact demographic/measurements used.
  /// Editing a field must not leave an apparently current estimate on screen.
  void _invalidateEnergyDraft() {
    _energyEstimate=null;
    _calculatedProfile=null;
    _calculatedBody=null;
    _calculationMeasurementIds=null;
  }

  NutritionPhoto? _photo;
  FoodVisionEstimate? _foodEstimate;
  bool _analyzing = false;
  String? _message;

  late final NutritionHistoryRepository _historyRepository;
  late final String _nutritionOwnerId;
  int _analysisEpoch=0;
  List<NutritionHistoryEntry> _history = const <NutritionHistoryEntry>[];
  bool _showFavoriteMealsOnly=false;

  @override
  void initState() {
    super.initState();
    var ownerId='guest';
    try{
      ownerId=Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    }catch(_){/* Guest nutrition stays offline and local. */}
    _nutritionOwnerId=ownerId;
    _historyRepository = NutritionHistoryRepository(
      Hive.box<dynamic>(HiveBoxes.metadata), ownerId:ownerId,
    );
    _history = _historyRepository.getEntries();
    try {
      final id = Supabase.instance.client.auth.currentUser?.id;
      if(id != null){
        _planRepository=NutritionGoalPlanRepository(
          Hive.box<dynamic>(HiveBoxes.metadata),id);
        _activePlan=_planRepository?.read();
      }
    }catch(_){/* Keep public nutrition guidance available offline. */}
  }

  /// Revocation and account changes clear memory, never the original local
  /// records. An in-flight Food Vision response cannot resurrect old values.
  void _clearSensitiveSessionState() {
    _analysisEpoch++;
    _photo=null;
    _foodEstimate=null;
    _analyzing=false;
    _invalidateEnergyDraft();
    _activePlan=null;
    _message=null;
  }

  bool get _sameNutritionOwner {
    try{
      return (Supabase.instance.client.auth.currentUser?.id ?? 'guest')==
        _nutritionOwnerId;
    }catch(_){return _nutritionOwnerId=='guest';}
  }

  @override
  void didUpdateWidget(covariant NutritionIntelligencePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed server check can revoke the grant while this route is
    // visible. Never retain numeric food/photo or energy output in that case.
    if(oldWidget.verifiedAdultNutritionAccess &&
        !widget.verifiedAdultNutritionAccess){
      _clearSensitiveSessionState();
    }else if(!oldWidget.verifiedAdultNutritionAccess &&
        widget.verifiedAdultNutritionAccess){
      _activePlan=_planRepository?.read();
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _dishHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final access=ref.watch(
      nutritionAccessStateProvider(widget.verifiedAdultNutritionAccess));
    final hasAdultAccess=access.canViewNumericNutrition;
    // Local profile updates can downgrade a previously verified adult even
    // without a new backend boolean. Revoke all numeric session caches.
    ref.listen<NutritionAccessState>(
      nutritionAccessStateProvider(widget.verifiedAdultNutritionAccess),
      (previous,next){
        if(previous?.canViewNumericNutrition==true &&
           !next.canViewNumericNutrition){
          setState(_clearSensitiveSessionState);
        }else if(previous?.canViewNumericNutrition==false &&
                 next.canViewNumericNutrition){
          setState(()=>_activePlan=_planRepository?.read());
        }
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Inteligente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            _HeroCard(colors: colors),
            const SizedBox(height: 16),
            if (!hasAdultAccess)
              _AdultGateCard(
                colors: colors,
                access: access,
                onRefreshAdultAccess: widget.onRefreshAdultAccess)
            else
              _buildEnergyPlanner(colors),
            const SizedBox(height: 16),
            _buildWellnessSummary(colors),
            const SizedBox(height: 16),
            _buildFoodVision(colors),
            const SizedBox(height: 16),
            _buildHistory(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyPlanner(ColorScheme colors) {
    final measurementRecords=ref.watch(bodyMeasurementProvider);
    final body = LatestBodyMeasurements.fromRecords(measurementRecords);
    final trend=NutritionWeightTrend.fromRecords(measurementRecords);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final sourceIds = body.fingerprint;
    final demographic = ref.watch(userExperienceProfileProvider).value;
    final review=_activePlan==null?null:
      NutritionPlanMeasurementReview.compare(_activePlan!,body);
    return Card(
      key:_energyFormKey,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Plan energético para adultos',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'STK Haven muestra un rango de referencia, no una cifra “perfecta”. '
              'Los ajustes son graduales y no sustituyen orientación profesional.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    onChanged:(_)=>setState(_invalidateEnergyDraft),
                    decoration: InputDecoration(
                      labelText: 'Edad',
                      hintText: demographic?.ageAt(DateTime.now())?.toString(),
                      helperText: 'De Perfil, o indícala para este cálculo.',
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('nutrition_measurements_source'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos de Medidas',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    body.weightKg == null
                        ? 'Peso: falta un registro válido'
                        : 'Peso: ${body.weightKg!.value.toStringAsFixed(1)} kg · '
                            '${dateFormat.format(body.weightKg!.recordedAt)}',
                  ),
                  Text(
                    body.heightCm == null
                        ? 'Altura: falta un registro válido'
                        : 'Altura: ${body.heightCm!.value.toStringAsFixed(1)} cm · '
                            '${dateFormat.format(body.heightCm!.recordedAt)}',
                  ),
                  if (widget.onOpenMeasurements != null)
                    TextButton.icon(
                      onPressed: widget.onOpenMeasurements,
                      icon: const Icon(Icons.straighten_rounded),
                      label: const Text('Actualizar en Medidas'),
                    ),
                ],
              ),
            ),
            if (_energyEstimate != null &&
                _calculationMeasurementIds != sourceIds)
              Text(
                'Hay medidas más recientes o modificadas. '
                'El resultado anterior no se actualizará sin tu confirmación.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyEquationSex>(
              key: ValueKey('energy_equation_${_equationSex?.name ?? demographic?.equationSexForEnergy?.name ?? 'none'}'),
              initialValue: _equationSex ?? demographic?.equationSexForEnergy,
              decoration: const InputDecoration(
                labelText: 'Parámetro fisiológico de la ecuación',
                helperText: 'Solo para estimar energía; no define tu identidad.',
              ),
              items: const [
                DropdownMenuItem(
                  value: EnergyEquationSex.female,
                  child: Text('Femenino'),
                ),
                DropdownMenuItem(
                  value: EnergyEquationSex.male,
                  child: Text('Masculino'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() {
                  _equationSex = value;
                  _invalidateEnergyDraft();
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyActivityLevel>(
              value: _activity,
              hint: const Text('Selecciona tu actividad'),
              decoration: const InputDecoration(
                labelText: 'Actividad habitual',
                helperText: 'Incluye también tu actividad fuera del entrenamiento.',
              ),
              items: const [
                DropdownMenuItem(
                  value: EnergyActivityLevel.sedentary,
                  child: Text('Baja'),
                ),
                DropdownMenuItem(
                  value: EnergyActivityLevel.light,
                  child: Text('Ligera'),
                ),
                DropdownMenuItem(
                  value: EnergyActivityLevel.moderate,
                  child: Text('Moderada'),
                ),
                DropdownMenuItem(
                  value: EnergyActivityLevel.high,
                  child: Text('Alta'),
                ),
                DropdownMenuItem(
                  value: EnergyActivityLevel.veryHigh,
                  child: Text('Muy alta'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() {
                  _activity = value;
                  _invalidateEnergyDraft();
                });
              },
            ),
            if(demographic?.trainingDaysPerWeek case final days?)
              Padding(
                padding:const EdgeInsets.only(top:6),
                child:Text('Tu perfil indica $days días de entrenamiento a la '
                  'semana. Eso no determina por sí solo tu actividad diaria; '
                  'selecciona el nivel que mejor te represente.',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:colors.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyGoal>(
              value: _goal,
              decoration: const InputDecoration(labelText: 'Objetivo'),
              items: const [
                DropdownMenuItem(
                  value: EnergyGoal.maintenance,
                  child: Text('Mantenimiento'),
                ),
                DropdownMenuItem(
                  value: EnergyGoal.gradualLoss,
                  child: Text('Ajuste gradual hacia pérdida'),
                ),
                DropdownMenuItem(
                  value: EnergyGoal.gradualGain,
                  child: Text('Ajuste gradual hacia ganancia'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() {
                  _goal = value;
                  _invalidateEnergyDraft();
                });
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _calculateEnergy,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calcular rango'),
            ),
            if (_energyEstimate case final estimate?) ...[
              const SizedBox(height: 16),
              _EnergyResultCard(estimate: estimate),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key:const ValueKey('nutrition_adult_macro_guide'),
                onPressed:()=>_showAdultMacroGuide(estimate),
                icon:const Icon(Icons.donut_small_outlined),
                label:const Text('Consultar macros de referencia (opcional)'),
              ),
              const SizedBox(height:8),
              FilledButton.icon(
                onPressed: _saveEnergyPlan,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Guardar este plan'),
              ),
            ],
            if (_activePlan case final plan?) ...[
              const SizedBox(height: 16),
              Text('Mi plan guardado',
                style:Theme.of(context).textTheme.titleMedium),
              Text(plan.isPaused
                  ? 'Sin objetivo activo · plan pausado'
                  : 'Objetivo: ${plan.estimate.targetLow}–'
                    '${plan.estimate.targetHigh} kcal estimadas',
                style:Theme.of(context).textTheme.bodyMedium),
              Text('Guardado el ${DateFormat('dd/MM/yyyy').format(plan.savedAt)}. '
                'Peso ${plan.weightKg.toStringAsFixed(1)} kg y altura '
                '${plan.heightCm.toStringAsFixed(1)} cm de Medidas.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant)),
              ExpansionTile(
                key:const ValueKey('nutrition_plan_snapshot_details'),
                tilePadding:EdgeInsets.zero,
                title:const Text('Origen de mi cálculo'),
                children:[
                  Text('Peso: ${plan.weightKg.toStringAsFixed(1)} kg, '
                    'registro del ${dateFormat.format(plan.weightRecordedAt)}. '
                    'Altura: ${plan.heightCm.toStringAsFixed(1)} cm, '
                    'registro del ${dateFormat.format(plan.heightRecordedAt)}.'),
                  const SizedBox(height:6),
                  Text('Edad indicada: ${plan.ageYears} años · '
                    'actividad: ${plan.activityLevel.name} · '
                    'objetivo: ${plan.goal.name}.'),
                  const SizedBox(height:6),
                  Text('Método: ${plan.estimate.method}. '
                    'Versión de fórmula: ${plan.formulaVersion}.'),
                  const SizedBox(height:6),
                  Text(plan.accessCheckedAt==null
                    ?'El registro anterior no conservaba fecha de '
                      'comprobación de acceso adulto.'
                    :'Acceso adulto consultado en servidor al guardar: '
                      '${DateFormat('dd/MM/yyyy HH:mm').format(plan.accessCheckedAt!.toLocal())}. '
                      'Esto no concede ni mantiene un permiso actual.'),
                  const SizedBox(height:8),
                ],
              ),
              if(review!=null && review.needsReview) ...[
                const SizedBox(height:8),
                Text(review.canRecalculate
                  ?'Tus registros de Medidas cambiaron desde que guardaste '
                    'este plan. Puedes revisar un nuevo cálculo; el plan '
                    'anterior no se modificará hasta que lo guardes.'
                  :'Faltan medidas válidas para revisar el plan. '
                    'El plan guardado se conserva sin cambios.',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:colors.onSurfaceVariant)),
                if(review.canRecalculate)
                  TextButton.icon(
                    key:const ValueKey('nutrition_review_changed_measures'),
                    onPressed:()=>_preparePlanReview(plan),
                    icon:const Icon(Icons.refresh_rounded),
                    label:const Text('Recalcular con Medidas actuales'),
                  )
                else if(widget.onOpenMeasurements!=null)
                  TextButton.icon(
                    onPressed:widget.onOpenMeasurements,
                    icon:const Icon(Icons.straighten_outlined),
                    label:const Text('Registrar medidas faltantes'),
                  ),
              ],
              if(plan.nextReviewAt!=null)
                Text('Revisión voluntaria: '
                  '${DateFormat('dd/MM/yyyy').format(plan.nextReviewAt!)}. '
                  'Nunca actualiza calorías por sí sola.',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:colors.onSurfaceVariant)),
              Wrap(spacing:8,runSpacing:6,children:[
                TextButton.icon(
                  key:const ValueKey('nutrition_pause_resume_plan'),
                  onPressed:()=>_togglePlanPaused(plan),
                  icon:Icon(plan.isPaused?Icons.play_circle_outline:
                    Icons.pause_circle_outline),
                  label:Text(plan.isPaused?'Retomar objetivo':
                    'Pausar objetivo'),
                ),
                TextButton.icon(
                  key:const ValueKey('nutrition_review_plan'),
                  onPressed:()=>_chooseReviewInterval(plan),
                  icon:const Icon(Icons.event_outlined),
                  label:const Text('Programar revisión'),
                ),
                TextButton.icon(
                  onPressed:()=>_confirmRemoveEnergyPlan(),
                  icon:const Icon(Icons.delete_outline),
                  label:const Text('Quitar plan'),
                ),
              ]),
            ],
            if(trend!=null) ...[
              const SizedBox(height:12),
              const Divider(),
              Text('Cambio entre registros de Medidas',
                style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:6),
              Text(
                '${dateFormat.format(trend.previousDate)}: '
                '${trend.previousWeightKg.toStringAsFixed(1)} kg · '
                '${dateFormat.format(trend.latestDate)}: '
                '${trend.latestWeightKg.toStringAsFixed(1)} kg',
                style:Theme.of(context).textTheme.bodyMedium),
              Text('Diferencia: ${trend.differenceKg.toStringAsFixed(1)} kg. '
                'No representa por sí sola éxito o fracaso.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant)),
              if(widget.onOpenMeasurements!=null)
                TextButton.icon(
                  onPressed:widget.onOpenMeasurements,
                  icon:const Icon(Icons.show_chart_rounded),
                  label:const Text('Ver historial completo en Medidas'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessSummary(ColorScheme colors) {
    final hydration=ref.watch(hydrationProvider);
    final water=ref.watch(hydrationPreferencesProvider);
    final steps=ref.watch(dailyStepsProvider);
    final stepPrefs=ref.watch(stepGoalPreferencesProvider);
    final history=ref.read(wellnessRepositoryProvider)
        .recentRecordedSteps(days:14);
    final stepSuggestion=WellnessGoalSuggestions.stepsFromBaseline(
      history.map((day)=>day.steps),
    );
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text('Bienestar conectado',
              style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:4),
            Text('Tus metas siguen siendo tuyas. Cambiar a volumen, '
              'mantenimiento o déficit no las modifica automáticamente.',
              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                color:colors.onSurfaceVariant)),
            const SizedBox(height:14),
            Row(children:[
              Icon(Icons.water_drop_outlined,color:colors.primary),
              const SizedBox(width:10),
              Expanded(child:Text('Agua: ${hydration.waterMl} ml / '
                '${water.targetMl} ml')),
            ]),
            const SizedBox(height:10),
            Row(children:[
              Icon(Icons.directions_walk_outlined,color:colors.primary),
              const SizedBox(width:10),
              Expanded(child:Text('Pasos: ${steps.steps} / '
                '${stepPrefs.targetSteps}')),
            ]),
            const SizedBox(height:10),
            if(steps.deviceSynced)
              Text(
                steps.lastSyncedAt == null
                  ? 'Pasos: fuente del dispositivo; hora no disponible.'
                  : 'Pasos del dispositivo · última sincronización: '
                    '${DateFormat('dd/MM HH:mm').format(steps.lastSyncedAt!.toLocal())}',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant),
              )
            else
              Text('Pasos registrados manualmente o sin sensor conectado.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant)),
            const SizedBox(height:8),
            Text('Hidratación: actividad, calor y necesidades personales '
              'importan más que la fase nutricional. Tu meta manual se conserva.',
              style:Theme.of(context).textTheme.bodySmall?.copyWith(
                color:colors.onSurfaceVariant)),
            if(water.goalChanges.isNotEmpty ||
               stepPrefs.goalChanges.isNotEmpty)
              Align(alignment:Alignment.centerLeft,child:TextButton.icon(
                key:const ValueKey('nutrition_wellness_goal_history'),
                onPressed:_showWellnessGoalHistory,
                icon:const Icon(Icons.history_rounded),
                label:const Text('Ver cambios de mis metas'),
              )),
            const SizedBox(height:8),
            Align(alignment:Alignment.centerLeft,child:TextButton.icon(
              key:const ValueKey('nutrition_review_water_target'),
              onPressed:()=>_reviewWaterTarget(),
              icon:const Icon(Icons.water_drop_outlined),
              label:const Text('Revisar mi meta de agua'),
            )),
            if(stepSuggestion==null)
              Text('Para sugerir pasos con fundamento necesitamos '
                'al menos 7 días registrados.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant))
            else if(stepSuggestion!=stepPrefs.targetSteps) ...[
              const SizedBox(height:8),
              Text('Tu actividad habitual sugiere aproximadamente '
                '$stepSuggestion pasos, según tus últimos registros.',
                style:Theme.of(context).textTheme.bodySmall),
              Align(alignment:Alignment.centerLeft,
                child:TextButton.icon(
                  icon:const Icon(Icons.tune_rounded),
                  label:const Text('Revisar sugerencia de pasos'),
                  onPressed:_reviewStepTarget,
                )),
            ],
          ],
        ),
      ),
    );
  }

  /// A bounded audit is kept next to each local preference, never uploaded.
  Future<void> _showWellnessGoalHistory() async {
    final water=ref.read(hydrationPreferencesProvider);
    final steps=ref.read(stepGoalPreferencesProvider);
    final dateFormat=DateFormat('dd/MM/yyyy HH:mm');
    String description(WellnessGoalChange change,String unit) {
      final context=change.source==WellnessGoalChangeSource.nutritionReview
        ?'Revisión desde Nutrición':'Ajuste manual';
      return '${change.previousTarget} → ${change.newTarget} $unit · '
        '${dateFormat.format(change.changedAt.toLocal())} · $context';
    }
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Cambios guardados de mis metas'),
      content:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisSize:MainAxisSize.min,
        children:[
          const Text('Solo en este dispositivo. No registra ingestas, '
            'calorías ni datos clínicos.'),
          const SizedBox(height:12),
          Text('Agua',style:Theme.of(ctx).textTheme.titleMedium),
          if(water.goalChanges.isEmpty)
            const Text('No hay cambios registrados.')
          else
            for(final change in water.goalChanges.reversed)
              Padding(padding:const EdgeInsets.symmetric(vertical:4),
                child:Text(description(change,'ml/día'))),
          const SizedBox(height:12),
          Text('Pasos',style:Theme.of(ctx).textTheme.titleMedium),
          if(steps.goalChanges.isEmpty)
            const Text('No hay cambios registrados.')
          else
            for(final change in steps.goalChanges.reversed)
              Padding(padding:const EdgeInsets.symmetric(vertical:4),
                child:Text(description(change,'pasos/día'))),
        ],
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
        child:const Text('Cerrar'))],
    ));
  }

  /// Only the user's explicit choice can update a step target.
  Future<void> _reviewStepTarget() async {
    final current=ref.read(stepGoalPreferencesProvider);
    final history=ref.read(wellnessRepositoryProvider)
      .recentRecordedSteps(days:14);
    final suggestion=WellnessGoalSuggestions.stepsFromBaseline(
      history.map((day)=>day.steps));
    if(suggestion==null){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Necesitamos al menos 7 días reales '
          'de pasos para ofrecer una sugerencia. Tu meta se conserva.')));
      return;
    }
    if(suggestion==current.targetSteps)return;
    final apply=await showDialog<bool>(
      context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Revisar meta de pasos'),
        content:Text('Meta actual: ${current.targetSteps}. '
          'Sugerencia según tus días registrados: $suggestion. '
          'No es una prescripción ni depende de tu objetivo calórico.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Mantener mi meta')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Aplicar sugerencia')),
        ],
      ),
    );
    if(apply==true && mounted){
      await ref.read(stepGoalPreferencesProvider.notifier)
        .setTargetSteps(suggestion,
          source:WellnessGoalChangeSource.nutritionReview);
    }
  }

  /// A nutrition-plan edit never changes either target. Offer an optional,
  /// one-time review rather than introducing a second set of Home controls.
  Future<void> _reviewWellnessAfterPlanSave() async {
    final water=ref.read(hydrationPreferencesProvider);
    final steps=ref.read(stepGoalPreferencesProvider);
    final history=ref.read(wellnessRepositoryProvider)
      .recentRecordedSteps(days:14);
    final stepSuggestion=WellnessGoalSuggestions.stepsFromBaseline(
      history.map((day)=>day.steps));
    final selected=await showDialog<String>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Tus metas de bienestar'),
        content:Text('Agua actual: ${water.targetMl} ml/día. '
          'Pasos actuales: ${steps.targetSteps}. '
          'Guardar el plan no modifica ninguna meta ni recordatorio. '
          '${stepSuggestion==null ? "Aún no hay 7 días de pasos para sugerir otra meta." : "Puedes revisar cada meta por separado."}'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Conservar mis metas')),
          TextButton(onPressed:()=>Navigator.pop(ctx,'water'),
            child:const Text('Revisar agua')),
          TextButton(
            onPressed:stepSuggestion==null?null:
              ()=>Navigator.pop(ctx,'steps'),
            child:const Text('Revisar pasos')),
        ],
      ));
    if(!mounted)return;
    if(selected=='water')await _reviewWaterTarget();
    if(selected=='steps')await _reviewStepTarget();
  }

  Future<void> _reviewWaterTarget() async {
    final current=ref.read(hydrationPreferencesProvider);
    var draft=current.targetMl.toDouble();
    var moreActivity=false;
    var hotWeather=false;
    var moreSweat=false;

    final chosen=await showModalBottomSheet<int>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(
          16,8,16,16+MediaQuery.viewInsetsOf(ctx).bottom),
        child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text('Revisar meta de hidratación',
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:8),
            const Text('El volumen, el déficit y el mantenimiento '
              'no indican cuánta agua necesita una persona. '
              'Considera tu actividad, calor, sudor y circunstancias '
              'de salud; estos campos solo ayudan a reflexionar, '
              'no calculan una prescripción.'),
            CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              title:const Text('Actividad prolongada'),
              value:moreActivity,
              onChanged:(v)=>update(()=>moreActivity=v??false),
            ),
            CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              title:const Text('Ambiente caluroso'),
              value:hotWeather,
              onChanged:(v)=>update(()=>hotWeather=v??false),
            ),
            CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              title:const Text('Sudoración elevada'),
              value:moreSweat,
              onChanged:(v)=>update(()=>moreSweat=v??false),
            ),
            const SizedBox(height:8),
            Text('Meta que eliges: ${draft.round()} ml/día',
              style:Theme.of(ctx).textTheme.titleMedium),
            Slider(
              key:const ValueKey('nutrition_water_target_slider'),
              min:1000,max:5000,divisions:16,
              value:draft.clamp(1000.0,5000.0).toDouble(),
              label:'${draft.round()} ml',
              onChanged:(v)=>update(()=>draft=v),
            ),
            const Text('No hay ajuste numérico automático por '
              'actividad o clima. Si tienes restricciones de líquidos '
              'u otra condición clínica, consulta con un profesional.'),
            const SizedBox(height:12),
            SizedBox(width:double.infinity,child:FilledButton(
              onPressed:()=>Navigator.pop(ctx,draft.round()),
              child:const Text('Revisar este valor'),
            )),
          ],
        )),
      )),
    );
    if(chosen==null || !mounted || chosen==current.targetMl)return;
    final contexts=<String>[
      if(moreActivity)'actividad prolongada',
      if(hotWeather)'ambiente caluroso',
      if(moreSweat)'sudoración elevada',
    ];
    final contextLabel=contexts.isEmpty
      ? 'No indicaste factores adicionales.'
      : 'Factores señalados: ${contexts.join(', ')}.';
    // Confirmation for water is entirely separate from any steps suggestion.
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Confirmar meta de agua'),
        content:Text('Actual: ${current.targetMl} ml/día. '
          'Nueva: $chosen ml/día. $contextLabel '
          'Es una elección manual, no una prescripción. '
          'Los pasos, el plan energético y los recordatorios '
          'no cambiarán.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Conservar mi meta')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Aplicar mi elección')),
        ],
      ),
    );
    if(confirmed!=true || !mounted)return;
    await ref.read(hydrationPreferencesProvider.notifier)
      .setTargetMl(chosen,
        source:WellnessGoalChangeSource.nutritionReview);
  }

  Widget _buildFoodVision(ColorScheme colors) {
    return Card(
      key:_foodFormKey,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Food Vision',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _hasAdultNumericAccess
                  ? 'Toma o sube una foto. La IA devuelve rangos, ingredientes, '
                      'porciones y nivel de confianza.'
                  : 'Toma o sube una foto. Mientras la cuenta no tenga verificación '
                      'adulta, la IA identifica alimentos y porciones sin mostrar '
                      'calorías ni macros numéricos.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _dishHintController,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Contexto opcional',
                hintText: 'Ej.: arroz con pollo, usé una cucharada de aceite',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (widget.cameraAvailable)
                  OutlinedButton.icon(
                    onPressed: _analyzing
                        ? null
                        : () => _pickAndAnalyze(NutritionPhotoSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Tomar foto'),
                  ),
                OutlinedButton.icon(
                  onPressed: _analyzing
                      ? null
                      : () => _pickAndAnalyze(NutritionPhotoSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir foto'),
                ),
                if (_photo != null)
                  FilledButton.tonalIcon(
                    onPressed: _analyzing ? null : () => _analyzePhoto(_photo!),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reanalizar con contexto'),
                  ),
              ],
            ),
            if (_photo case final photo?) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Image.memory(
                    photo.bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                photo.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
            if (_analyzing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Analizando plato…'),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: colors.error),
              ),
            ],
            if (_foodEstimate case final estimate?
                when !estimate.numericNutritionAvailable ||
                     _hasAdultNumericAccess) ...[
              const SizedBox(height: 16),
              _FoodVisionResultCard(estimate: estimate),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _saveCurrentEstimate(estimate),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Guardar resultado local'),
                  ),
                  if(_hasAdultNumericAccess && _activePlan!=null &&
                     !_activePlan!.isPaused && estimate.numericNutritionAvailable &&
                     estimate.caloriesLow!=null && estimate.caloriesHigh!=null)
                    OutlinedButton.icon(
                      key:const ValueKey('foodvision_plan_context'),
                      onPressed:()=>_showFoodPlanContext(estimate),
                      icon:const Icon(Icons.compare_arrows_rounded),
                      label:const Text('Ver en contexto de mi plan'),
                    ),
                  if (_photo != null)
                    OutlinedButton.icon(
                      onPressed: _analyzing
                          ? null
                          : () => _editStructuredCorrection(estimate),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Corregir ingredientes/porciones'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showFoodPlanContext(FoodVisionEstimate estimate) async {
    final plan=_activePlan;
    if(!_hasAdultNumericAccess || plan==null || plan.isPaused ||
       !estimate.numericNutritionAvailable ||
       estimate.caloriesLow==null || estimate.caloriesHigh==null){
      return;
    }
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Referencias nutricionales'),
      content:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Plato estimado: ${estimate.caloriesLow}–'
            '${estimate.caloriesHigh} kcal.'),
          const SizedBox(height:12),
          Text('Plan diario guardado: ${plan.estimate.targetLow}–'
            '${plan.estimate.targetHigh} kcal.'),
          const SizedBox(height:12),
          const Text('Son rangos aproximados, no mediciones. '
            'No se añadirá esta comida a un contador diario, '
            'ni se descontarán calorías del plan.'),
        ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),
          child:const Text('Entendido')),
      ],
    ));
  }

  void _useFrequentDish(String name) {
    if(_analyzing)return;
    setState(() {
      _dishHintController.text=name;
      _dishHintController.selection=TextSelection.collapsed(offset:name.length);
      // A dish-name shortcut never triggers a camera, upload or analysis.
      _foodEstimate=null;
      _photo=null;
      _message='Nombre listo. Puedes elegir una foto si deseas analizarlo.';
    });
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted)return;
      final target=_foodFormKey.currentContext;
      if(target!=null)Scrollable.ensureVisible(target,
        duration:const Duration(milliseconds:250),
        curve:Curves.easeOut,alignment:0.05);
    });
  }

  Widget _buildHistory(ColorScheme colors) {
    final frequent=_historyRepository.frequentDishes();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Historial local',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: _confirmClearHistory,
                    child: const Text('Borrar todo'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Solo se guarda cuando tú lo eliges. Las fotos nunca se almacenan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            if (_history.isNotEmpty)
              Wrap(spacing:8,runSpacing:8,children:[
                ChoiceChip(
                  label:const Text('Todos los análisis'),
                  selected:!_showFavoriteMealsOnly,
                  onSelected:(_)=>setState(()=>_showFavoriteMealsOnly=false),
                ),
                ChoiceChip(
                  key:const ValueKey('nutrition_favorite_meals_filter'),
                  label:const Text('Favoritos'),
                  selected:_showFavoriteMealsOnly,
                  onSelected:(_)=>setState(()=>_showFavoriteMealsOnly=true),
                ),
              ]),
            if(frequent.isNotEmpty) ...[
              const SizedBox(height:12),
              Text('Comidas frecuentes de tu historial',
                style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:4),
              Text('Son nombres de análisis que elegiste guardar. '
                'Usar uno no inicia una foto ni un conteo de comidas.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant)),
              const SizedBox(height:8),
              Wrap(spacing:8,runSpacing:6,children:[
                for(final dish in frequent)
                  ActionChip(
                    key:ValueKey('nutrition_frequent_${dish.toLowerCase()}'),
                    label:Text(dish,maxLines:1,
                      overflow:TextOverflow.ellipsis),
                    tooltip:'Usar $dish como contexto opcional',
                    onPressed:_analyzing?null:()=>_useFrequentDish(dish),
                  ),
              ]),
            ],
            const SizedBox(height:8),
            if (_historyRepository.hasLegacyEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Historial anterior en este dispositivo'),
                subtitle: const Text('Hay análisis antiguos sin cuenta asignada. '
                  'Puedes trasladarlos a esta cuenta voluntariamente.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importLegacyHistory,
              ),
            if (_history.isEmpty)
              const Text('Aún no has guardado análisis.')
            else if(_showFavoriteMealsOnly &&
                !_history.any((entry)=>entry.isFavorite))
              const Text('Todavía no tienes comidas favoritas.')
            else
              for (final entry in _history.where(
                (entry)=>!_showFavoriteMealsOnly || entry.isFavorite).take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text(
                    entry.estimate.dishName.isEmpty
                        ? 'Plato analizado'
                        : entry.estimate.dishName,
                  ),
                  subtitle: Text(_historySubtitle(entry)),
                  onTap: () => setState(() {
                    if(entry.estimate.numericNutritionAvailable &&
                        !_hasAdultNumericAccess){
                      _foodEstimate=null;
                      _message='Este análisis contiene cifras de una sesión '
                        'adulta anterior. Verifica acceso para consultarlas.';
                    }else{
                      _foodEstimate = entry.estimate;
                      _message = null;
                    }
                    _dishHintController.text = entry.dishHint;
                    _photo = null;
                  }),
                  trailing: Row(mainAxisSize:MainAxisSize.min,children:[
                    IconButton(
                      tooltip:entry.isFavorite
                        ?'Quitar de favoritos':'Añadir a favoritos',
                      onPressed:()=>_setHistoryFavorite(entry),
                      icon:Icon(entry.isFavorite
                        ?Icons.favorite_rounded:Icons.favorite_border_rounded,
                        color:entry.isFavorite?colors.primary:null),
                    ),
                    IconButton(
                      tooltip:'Eliminar',
                      onPressed:()=>_deleteHistoryEntry(entry.id),
                      icon:const Icon(Icons.delete_outline),
                    ),
                  ]),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _setHistoryFavorite(NutritionHistoryEntry entry) async {
    try{
      await _historyRepository.setFavorite(entry.id,!entry.isFavorite);
      if(mounted){
        setState(()=>_history=_historyRepository.getEntries());
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No se pudo actualizar el favorito.')));
    }
  }

  String _historySubtitle(NutritionHistoryEntry entry) {
    final date = entry.analyzedAt.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final details = <String>['$day/$month/${date.year} $hour:$minute'];
    if (_hasAdultNumericAccess &&
        entry.estimate.numericNutritionAvailable &&
        entry.estimate.caloriesLow != null &&
        entry.estimate.caloriesHigh != null) {
      details.add(
        '${entry.estimate.caloriesLow}–${entry.estimate.caloriesHigh} kcal',
      );
    }
    return details.join(' · ');
  }

  Future<void> _saveCurrentEstimate(FoodVisionEstimate estimate) async {
    if(!_sameNutritionOwner)return;
    if(estimate.numericNutritionAvailable){
      final stillVerified=await NutritionAdultAccessService(
        Supabase.instance.client).hasVerifiedAccess();
      if(!mounted || !_sameNutritionOwner)return;
      if(!stillVerified){
        setState(_clearSensitiveSessionState);
        widget.onRefreshAdultAccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Tu permiso adulto cambió. '
            'No se guardaron cifras nutricionales.')));
        return;
      }
    }
    if(estimate.numericNutritionAvailable && !_hasAdultNumericAccess){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('El acceso adulto ha cambiado. Vuelve a consultar.')));
      return;
    }
    final now = DateTime.now();
    final id = 'food_${now.microsecondsSinceEpoch}';
    if(!_sameNutritionOwner)return;
    await _historyRepository.save(
      NutritionHistoryEntry(
        id: id,
        analyzedAt: now,
        dishHint: _dishHintController.text.trim(),
        estimate: estimate,
      ),
    );
    if (!mounted || !_sameNutritionOwner) return;
    setState(() => _history = _historyRepository.getEntries());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resultado guardado localmente. La foto no se guardó.'),
      ),
    );
  }

  Future<void> _importLegacyHistory() async {
    final confirmed=await showDialog<bool>(
      context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Trasladar historial anterior'),
        content:const Text(
          'Estos análisis se guardaron antes de separar historiales por '
          'cuenta. Trasladarlos a tu cuenta en este dispositivo evita que '
          'otras cuentas vean esos registros. No se subirán fotos ni archivos. '
          'Hazlo solo si reconoces este historial como tuyo.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Trasladar a mi cuenta')),
        ],
      ),
    );
    if(confirmed!=true || !mounted)return;
    try{
      final count=await _historyRepository.importLegacyEntries();
      if(!mounted)return;
      setState(()=>_history=_historyRepository.getEntries());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('$count registros locales trasladados.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No se completó la importación. '
          'Tus datos anteriores permanecen guardados.')));
    }
  }

  Future<void> _deleteHistoryEntry(String id) async {
    await _historyRepository.delete(id);
    if (!mounted) return;
    setState(() => _history = _historyRepository.getEntries());
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
          'Se eliminarán todos los análisis de Food Vision guardados en este '
          'dispositivo. Esta acción no afecta otras áreas de STK Haven.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _historyRepository.clear();
    if (!mounted) return;
    setState(() => _history = const <NutritionHistoryEntry>[]);
  }

  void _calculateEnergy() {
    try {
      final ageText = _ageController.text.trim();
      final age = ageText.isEmpty
          ? ref.read(userExperienceProfileProvider).value?.ageAt(DateTime.now())
          : int.tryParse(ageText);
      if (age == null) {
        throw const FormatException('Indica tu edad o complétala en Perfil.');
      }
      final body = LatestBodyMeasurements.fromRecords(
        ref.read(bodyMeasurementProvider),
      );
      final height = body.heightCm?.value;
      final weight = body.weightKg?.value;
      if (height == null || weight == null) {
        throw const FormatException('Registra peso y altura en Medidas.');
      }
      final equationSex = _equationSex ??
          ref.read(userExperienceProfileProvider).value?.equationSexForEnergy;
      if (equationSex == null) {
        throw const FormatException('Selecciona el parámetro de la ecuación.');
      }
      final activity=_activity;
      if(activity==null){
        throw const FormatException(
          'Selecciona tu actividad habitual antes de calcular.');
      }
      final profile=AdultEnergyProfile(
        ageYears: age,
        heightCm: height,
        weightKg: weight,
        equationSex: equationSex,
        activityLevel: activity,
        goal: _goal,
      );
      final estimate = const AdultEnergyPlanner().calculate(profile);
      setState(() {
        _energyEstimate = estimate;
        _calculatedProfile = profile;
        _calculatedBody = body;
        _calculationMeasurementIds = body.fingerprint;
        _message = null;
      });
    } catch (error) {
      setState(() {
        _energyEstimate = null;
        _message = error.toString();
      });
    }
  }

  void _preparePlanReview(NutritionGoalPlan plan) {
    if(!_hasAdultNumericAccess)return;
    final currentAge=ref.read(userExperienceProfileProvider).value
      ?.ageAt(DateTime.now());
    setState((){
      // This changes editable form fields, NOT the saved plan or Medidas.
      _ageController.text=(currentAge??plan.ageYears).toString();
      _equationSex=plan.equationSex;
      _activity=plan.activityLevel;
      _goal=plan.goal;
      _invalidateEnergyDraft();
    });
    final target=_energyFormKey.currentContext;
    if(target!=null){
      Scrollable.ensureVisible(target,
        duration:const Duration(milliseconds:300),
        curve:Curves.easeOut,
        alignment:0.04);
    }
  }

  Future<void> _togglePlanPaused(NutritionGoalPlan current) async {
    final repo=_planRepository;
    if(repo==null)return;
    if(current.isPaused){
      final verified=await NutritionAdultAccessService(
        Supabase.instance.client).hasVerifiedAccess();
      if(!mounted)return;
      final age=ref.read(userExperienceProfileProvider).value?.ageAt(DateTime.now());
      if(!verified || (age!=null && age<18)){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Solo una cuenta adulta verificada puede retomar el plan.')));
        return;
      }
    }
    try{
      final next=current.copyWith(isPaused:!current.isPaused);
      await repo.save(next);
      if(mounted)setState(()=>_activePlan=next);
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No se pudo actualizar el estado del plan.')));
    }
  }

  Future<void> _chooseReviewInterval(NutritionGoalPlan current) async {
    final weeks=await showModalBottomSheet<int>(
      context:context,
      showDragHandle:true,
      builder:(ctx)=>SafeArea(child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          const ListTile(
            title:Text('Revisar mi plan'),
            subtitle:Text('Es una fecha de referencia voluntaria. '
              'No recalcula calorías ni envía recordatorios automáticamente.')),
          ListTile(
            title:const Text('En 2 semanas'),
            onTap:()=>Navigator.pop(ctx,2)),
          ListTile(
            title:const Text('En 4 semanas'),
            onTap:()=>Navigator.pop(ctx,4)),
          ListTile(
            title:const Text('Sin fecha de revisión'),
            onTap:()=>Navigator.pop(ctx,0)),
        ],
      )),
    );
    if(weeks==null || !mounted || _planRepository==null)return;
    final next=current.copyWith(
      nextReviewAt:weeks==0?null:DateTime.now().add(
        Duration(days:7*weeks)),
      clearNextReview:weeks==0,
    );
    try{
      await _planRepository!.save(next);
      if(mounted)setState(()=>_activePlan=next);
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No se pudo guardar la revisión.')));
    }
  }

  Future<void> _confirmRemoveEnergyPlan() async {
    final confirmed=await showDialog<bool>(
      context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Quitar objetivo nutricional'),
        content:const Text('Se elimina solo este plan local. '
          'Tus registros de Medidas, agua, pasos y Food Vision se conservan.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Quitar plan')),
        ],
      ));
    if(confirmed!=true || !mounted)return;
    try{
      await _planRepository?.clear();
      if(mounted)setState(()=>_activePlan=null);
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No se pudo borrar el plan.')));
    }
  }

  Future<void> _showAdultMacroGuide(EnergyEstimate estimate) async {
    final age=ref.read(userExperienceProfileProvider).value
      ?.ageAt(DateTime.now());
    // The published adult AMDR covers age 19+, unlike the adult energy
    // gate which may legitimately allow an 18-year-old.
    if(age==null || age<19 || !_hasAdultNumericAccess){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Esta guía general requiere edad de 19 años o más '
          'en Perfil y acceso adulto verificado.')));
      return;
    }
    final verified=await NutritionAdultAccessService(
      Supabase.instance.client).hasVerifiedAccess();
    if(!mounted || !verified || !_hasAdultNumericAccess)return;

    late final AdultMacroGuide macros;
    try{
      macros=AdultMacroGuide.fromEnergyEstimate(estimate);
    }catch(_){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No se puede obtener una referencia de macros '
          'con el rango de energía actual.')));
      return;
    }
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Macronutrientes: orientación general'),
      content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Rangos amplios para adultos sanos (19+), basados '
            'en referencias AMDR. No son una meta individual de gimnasio.'),
          const SizedBox(height:14),
          Text('Proteínas · 10–35 %: '
            '${macros.proteinGramsLow}–${macros.proteinGramsHigh} g/día'),
          const SizedBox(height:8),
          Text('Carbohidratos · 45–65 %: '
            '${macros.carbsGramsLow}–${macros.carbsGramsHigh} g/día'),
          const SizedBox(height:8),
          Text('Grasas · 20–35 %: '
            '${macros.fatGramsLow}–${macros.fatGramsHigh} g/día'),
          const SizedBox(height:14),
          const Text('Los intervalos son independientes: no se deben '
            'sumar sus máximos. No se guardan ni se aplican como dieta. '
            'Embarazo, condiciones médicas o necesidades alimentarias '
            'específicas requieren asesoramiento profesional.'),
          const SizedBox(height:10),
          const Text('Fuente: National Academies / Health Canada, '
            'rangos AMDR para adultos.'),
        ],
      )),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),
          child:const Text('Entendido')),
      ],
    ));
  }

  Future<void> _saveEnergyPlan() async {
    final estimate=_energyEstimate;
    final profile=_calculatedProfile;
    final body=_calculatedBody;
    final repo=_planRepository;
    if(estimate==null || profile==null || body==null || repo==null ||
       body.weightKg==null || body.heightCm==null)return;

    // Never trust local age or a stale widget flag to grant access.
    final verified=await NutritionAdultAccessService(
      Supabase.instance.client).hasVerifiedAccess();
    if(!mounted)return;
    final declaredAge=ref.read(userExperienceProfileProvider).value
      ?.ageAt(DateTime.now());
    if(!verified || (declaredAge!=null && declaredAge<18)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('El plan requiere una cuenta adulta verificada.')));
      return;
    }
    final current=LatestBodyMeasurements.fromRecords(
      ref.read(bodyMeasurementProvider));
    if(current.fingerprint!=_calculationMeasurementIds){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Han cambiado tus medidas. Calcula de nuevo antes de guardar.')));
      return;
    }
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(
        title:const Text('Guardar referencia nutricional'),
        content:const Text('Se guardará en este dispositivo un rango '
          'estimado y las medidas fechadas usadas. No es una prescripción '
          'ni cambia automáticamente tus metas de agua o pasos.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Guardar plan')),
        ],
      ));
    if(confirmed!=true || !mounted)return;
    // The permission checked before opening the dialog may have expired or
    // been revoked while the user was reading it. Recheck before persisting,
    // and never write an account-scoped plan into a different user's box.
    final freshVerified=await NutritionAdultAccessService(
      Supabase.instance.client).hasVerifiedAccess();
    if(!mounted)return;
    if(!freshVerified || !_hasAdultNumericAccess ||
       Supabase.instance.client.auth.currentUser?.id!=repo.ownerId){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('El acceso adulto cambió. No se guardó el plan.')));
      return;
    }
    final plan=NutritionGoalPlan(
      savedAt:DateTime.now(),
      accessCheckedAt:DateTime.now().toUtc(),
      weightRecordId:body.weightKg!.recordId,
      heightRecordId:body.heightCm!.recordId,
      weightRecordedAt:body.weightKg!.recordedAt,
      heightRecordedAt:body.heightCm!.recordedAt,
      weightKg:profile.weightKg,
      heightCm:profile.heightCm,
      ageYears:profile.ageYears,
      equationSex:profile.equationSex,
      activityLevel:profile.activityLevel,
      goal:profile.goal,
      estimate:estimate,
    );
    try{
      await repo.save(plan);
      if(mounted){
        setState(()=>_activePlan=plan);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:const Text('Plan guardado. Las metas de agua y pasos '
            'no se han modificado.'),
          action:SnackBarAction(
            label:'Revisar metas',
            onPressed:()=>_reviewWellnessAfterPlanSave(),
          ),
        ));
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No se pudo guardar el plan.')));
    }
  }

  Future<void> _editStructuredCorrection(
    FoodVisionEstimate estimate,
  ) async {
    final photo = _photo;
    if (photo == null) return;

    final draft = await showDialog<FoodVisionCorrectionDraft>(
      context: context,
      builder: (_) => _FoodVisionCorrectionDialog(
        initial: FoodVisionCorrectionDraft.fromEstimate(
          estimate,
          extraContext: _dishHintController.text.trim(),
        ),
      ),
    );
    if (!mounted || draft == null) return;

    final correctionContext = draft.toReanalysisContext();
    setState(() {
      _dishHintController.text = correctionContext;
      _dishHintController.selection = TextSelection.collapsed(
        offset: _dishHintController.text.length,
      );
    });
    await _analyzePhoto(photo);
  }

  Future<void> _pickAndAnalyze(NutritionPhotoSource source) async {
    final photo = await widget.photoPicker(source);
    if (!mounted || photo == null) return;

    setState(() {
      _photo = photo;
      _foodEstimate = null;
      _message = null;
    });
    await _analyzePhoto(photo);
  }

  Future<void> _analyzePhoto(NutritionPhoto photo) async {
    final epoch=++_analysisEpoch;
    final owner=_nutritionOwnerId;
    setState(() {
      _foodEstimate = null;
      _message = null;
      _analyzing = true;
    });

    try {
      final estimate = await FoodVisionService(Supabase.instance.client).analyze(
        imageBytes: photo.bytes,
        mimeType: photo.mimeType,
        adultNumericNutrition: _hasAdultNumericAccess,
        dishHint: _dishHintController.text,
      );
      if (!mounted || epoch!=_analysisEpoch ||
          !_sameNutritionOwner || owner!=_nutritionOwnerId)return;
      // An authorization may expire during a slow image upload. Requery the
      // actual server before exposing ANY numeric result from that response.
      if(estimate.numericNutritionAvailable){
        final stillVerified=await NutritionAdultAccessService(
          Supabase.instance.client).hasVerifiedAccess();
        if(!mounted || epoch!=_analysisEpoch ||
           !_sameNutritionOwner || owner!=_nutritionOwnerId)return;
        if(!stillVerified || !_hasAdultNumericAccess){
          setState((){
            _clearSensitiveSessionState();
            _message='El acceso adulto cambió. '
              'Vuelve a analizar sin datos numéricos.';
          });
          widget.onRefreshAdultAccess?.call();
          return;
        }
      }
      setState(() => _foodEstimate = estimate);
    } catch (_) {
      if (!mounted || epoch!=_analysisEpoch || !_sameNutritionOwner)return;
      setState(() => _message='No se pudo analizar el plato. '
        'Comprueba la conexión e inténtalo de nuevo.');
    } finally {
      if (mounted && epoch==_analysisEpoch)
        setState(() => _analyzing = false);
    }
  }
}

class _FoodVisionCorrectionDialog extends StatefulWidget {
  final FoodVisionCorrectionDraft initial;

  const _FoodVisionCorrectionDialog({required this.initial});

  @override
  State<_FoodVisionCorrectionDialog> createState() =>
      _FoodVisionCorrectionDialogState();
}

class _FoodVisionCorrectionDialogState
    extends State<_FoodVisionCorrectionDialog> {
  late final TextEditingController _dishName;
  late final TextEditingController _extraContext;
  late final List<_FoodVisionCorrectionItemControllers> _items;

  @override
  void initState() {
    super.initState();
    _dishName = TextEditingController(text: widget.initial.dishName);
    _extraContext = TextEditingController(text: widget.initial.extraContext);
    _items = widget.initial.items
        .map(_FoodVisionCorrectionItemControllers.fromItem)
        .toList(growable: true);
  }

  @override
  void dispose() {
    _dishName.dispose();
    _extraContext.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir análisis'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _dishName,
                decoration: const InputDecoration(
                  labelText: 'Nombre del plato',
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _items.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: _items[i].name,
                                decoration: const InputDecoration(
                                  labelText: 'Ingrediente',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _items[i].portion,
                                decoration: const InputDecoration(
                                  labelText: 'Porción / descripción',
                                  hintText: 'Ej.: 1 taza, porción pequeña',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar ingrediente',
                          onPressed: () => setState(() {
                            final removed = _items.removeAt(i);
                            removed.dispose();
                          }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _items.length >= 24
                      ? null
                      : () => setState(
                            () => _items.add(
                              _FoodVisionCorrectionItemControllers.empty(),
                            ),
                          ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir ingrediente'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _extraContext,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Contexto adicional',
                  hintText:
                      'Ej.: la salsa estaba aparte; no llevaba aceite adicional',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              FoodVisionCorrectionDraft(
                dishName: _dishName.text.trim(),
                items: [
                  for (final item in _items)
                    if (item.name.text.trim().isNotEmpty ||
                        item.portion.text.trim().isNotEmpty)
                      FoodVisionCorrectionItem(
                        name: item.name.text.trim(),
                        portionDescription: item.portion.text.trim(),
                      ),
                ],
                extraContext: _extraContext.text.trim(),
              ),
            );
          },
          child: const Text('Reanalizar'),
        ),
      ],
    );
  }
}

class _FoodVisionCorrectionItemControllers {
  final TextEditingController name;
  final TextEditingController portion;

  _FoodVisionCorrectionItemControllers({
    required this.name,
    required this.portion,
  });

  factory _FoodVisionCorrectionItemControllers.fromItem(
    FoodVisionCorrectionItem item,
  ) {
    return _FoodVisionCorrectionItemControllers(
      name: TextEditingController(text: item.name),
      portion: TextEditingController(text: item.portionDescription),
    );
  }

  factory _FoodVisionCorrectionItemControllers.empty() {
    return _FoodVisionCorrectionItemControllers(
      name: TextEditingController(),
      portion: TextEditingController(),
    );
  }

  void dispose() {
    name.dispose();
    portion.dispose();
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('nutrition_compact_plan_header'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: colors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi plan STK',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800)),
                Text('Nutrición, actividad y hábitos en un solo lugar.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdultGateCard extends StatelessWidget {
  const _AdultGateCard({
    required this.colors,
    required this.access,
    this.onRefreshAdultAccess,
  });

  final ColorScheme colors;
  final NutritionAccessState access;
  final VoidCallback? onRefreshAdultAccess;

  @override
  Widget build(BuildContext context) {
    final title=switch(access){
      NutritionAccessState.minor=>'Hábitos para crecer con salud',
      NutritionAccessState.ageUnknown=>'Tu bienestar, a tu ritmo',
      NutritionAccessState.adultUnverified=>'Acceso calórico pendiente de verificación',
      NutritionAccessState.adultVerified=>'Tu plan nutricional',
    };
    final message=switch(access){
      NutritionAccessState.minor=>
        'Entrena y cuida tus hábitos sin contar calorías ni restringir '
        'alimentos. Prioriza comer variado, descansar y progresar '
        'según tu experiencia.',
      NutritionAccessState.ageUnknown=>
        'Puedes usar Food Vision, registrar agua y pasos y entrenar '
        'sin indicar tu edad.',
      NutritionAccessState.adultUnverified=>
        'Tu cuenta aún no tiene verificación adulta en el servidor. '
        'El proceso externo de verificación no está disponible en esta '
        'versión; no basta con cambiar tu fecha de nacimiento. '
        'Puedes seguir usando agua, pasos y Food Vision descriptivo.',
      NutritionAccessState.adultVerified=>
        'Acceso adulto confirmado.',
    };
    return Container(
      key:const ValueKey('nutrition_access_state_panel'),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        border:Border.all(color:colors.outlineVariant),
        borderRadius:BorderRadius.circular(18),
        color:colors.surfaceContainerLow,
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(access.isMinor?Icons.spa_outlined:
            Icons.info_outline_rounded,color:colors.primary,size:22),
          const SizedBox(width:10),
          Expanded(child:Text(title,
            style:Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight:FontWeight.w800))),
        ]),
        const SizedBox(height:8),
        Text(message,style:Theme.of(context).textTheme.bodyMedium?.copyWith(
          color:colors.onSurfaceVariant)),
        if(access==NutritionAccessState.adultUnverified &&
           onRefreshAdultAccess!=null)
          Align(alignment:Alignment.centerLeft,
            child:TextButton.icon(
              onPressed:onRefreshAdultAccess,
              icon:const Icon(Icons.refresh_rounded),
              label:const Text('Volver a comprobar acceso'),
            )),
        Theme(
          data:Theme.of(context).copyWith(
            dividerColor:Colors.transparent,
          ),
          child:ExpansionTile(
            key:const ValueKey('nutrition_how_it_works'),
            tilePadding:EdgeInsets.zero,
            childrenPadding:const EdgeInsets.only(bottom:8),
            title:Text('¿Cómo funciona?',
              style:Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight:FontWeight.w600)),
            children:[
              Text(
                access==NutritionAccessState.minor
                  ? 'En menores no habilitamos metas calóricas ni dietas '
                    'restrictivas. Para necesidades nutricionales '
                    'específicas consulta a un profesional cualificado.'
                  : access==NutritionAccessState.ageUnknown
                    ? 'La fecha que agregues en Perfil es opcional, '
                      'y no sirve como verificación de mayoría de edad. '
                      'Food Vision funciona en modo descriptivo.'
                    : 'Los rangos calóricos solo se habilitan con un permiso '
                      'válido del servidor. La app aún no dispone de un '
                      'proceso externo para solicitarlo. Mientras tanto, '
                      'Food Vision sigue disponible en modo descriptivo.',
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _EnergyResultCard extends StatelessWidget {
  const _EnergyResultCard({required this.estimate});

  final EnergyEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${estimate.targetLow}–${estimate.targetHigh} kcal/día',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Mantenimiento estimado: '
            '${estimate.maintenanceLow}–${estimate.maintenanceHigh} kcal/día',
          ),
          const SizedBox(height: 10),
          for (final assumption in estimate.assumptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $assumption'),
            ),
        ],
      ),
    );
  }
}

class _FoodVisionResultCard extends StatelessWidget {
  const _FoodVisionResultCard({required this.estimate});

  final FoodVisionEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            estimate.dishName.isEmpty ? 'Plato analizado' : estimate.dishName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('Confianza: ${_confidenceLabel(estimate.confidence)}'),
          if (estimate.numericNutritionAvailable &&
              estimate.caloriesLow != null &&
              estimate.caloriesHigh != null) ...[
            const SizedBox(height: 8),
            Text(
              '${estimate.caloriesLow}–${estimate.caloriesHigh} kcal estimadas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          if (estimate.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in estimate.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        [
                          item.name,
                          if (item.portionDescription.isNotEmpty)
                            item.portionDescription,
                          if (estimate.numericNutritionAvailable &&
                              item.caloriesLow != null &&
                              item.caloriesHigh != null)
                            '${item.caloriesLow}–${item.caloriesHigh} kcal',
                        ].join(' · '),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (estimate.assumptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Supuestos',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final value in estimate.assumptions) Text('• $value'),
          ],
          if (estimate.questions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Para afinar',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final value in estimate.questions) Text('• $value'),
          ],
          if (estimate.disclaimer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              estimate.disclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _confidenceLabel(FoodVisionConfidence value) {
    return switch (value) {
      FoodVisionConfidence.low => 'baja',
      FoodVisionConfidence.medium => 'media',
      FoodVisionConfidence.high => 'alta',
    };
  }
}
