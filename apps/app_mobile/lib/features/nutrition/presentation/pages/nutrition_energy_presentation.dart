part of 'nutrition_intelligence_page.dart';

mixin _NutritionEnergyPresentation on _NutritionPageStateBase {
  @override
  Widget _buildEnergyPlanner(ColorScheme colors) {
    final measurementRecords=ref.watch(bodyMeasurementProvider);
    final body = LatestBodyMeasurements.fromRecords(measurementRecords);
    final trend=NutritionWeightTrend.fromRecords(measurementRecords);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final sourceIds = body.fingerprint;
    final demographic = ref.watch(userExperienceProfileProvider).value;
    final permittedDemographics=demographic?.optionalDemographicsConsented==true
      ?demographic:null;
    final recordedSessions=ref.watch(workoutHistoryProvider);
    final activitySuggestion=AdultActivitySuggestionPolicy.suggest(
      recordedSteps:ref.read(wellnessRepositoryProvider)
        .recentRecordedSteps(days:14),
      sessions:recordedSessions,
      now:DateTime.now(),
    );
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
                        ?.copyWith(fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800)]),
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
                  width: double.infinity,
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    onChanged:(_)=>setState(_invalidateEnergyDraft),
                    decoration: InputDecoration(
                      labelText: 'Edad',
                      hintText: permittedDemographics?.ageAt(DateTime.now())
                        ?.toString(),
                      helperText: 'De Perfil o para este cálculo.',
                      helperMaxLines: 3,
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyEquationSex>(
              key: ValueKey('energy_equation_${_equationSex?.name ?? permittedDemographics?.equationSexForEnergy?.name ?? 'none'}'),
              initialValue: _equationSex ??
                permittedDemographics?.equationSexForEnergy,
              decoration: const InputDecoration(
                labelText: 'Parámetro fisiológico de la ecuación',
                helperText: 'Solo para estimar energía; no define tu identidad.',
                helperMaxLines: 3,
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
              key:ValueKey('nutrition_activity_${_activity?.name ?? 'none'}'),
              initialValue: _activity,
              hint: const Text('Selecciona tu actividad'),
              decoration: const InputDecoration(
                labelText: 'Actividad habitual',
                helperText: 'Incluye también tu actividad fuera del entrenamiento.',
                helperMaxLines: 3,
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
            if(activitySuggestion case final suggested?) ...[
              const SizedBox(height:6),
              Text('Sugerencia orientativa: ${suggested.label}. '
                'Basada en ${suggested.recordedStepDays} días con sensor '
                'y ${suggested.recordedTrainingDays} días con sesiones '
                'completadas. No suma el entrenamiento a los pasos '
                'ni conoce toda tu actividad diaria.',
                key:const ValueKey('nutrition_activity_evidence'),
                style:Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:colors.onSurfaceVariant)),
              Align(alignment:Alignment.centerLeft,
                child:TextButton.icon(
                  key:const ValueKey('nutrition_activity_suggest_apply'),
                  onPressed:_activity==suggested.level?null:()=>setState((){
                    _activity=suggested.level;
                    _invalidateEnergyDraft();
                  }),
                  icon:const Icon(Icons.fact_check_outlined),
                  label:const Text('Usar sugerencia y revisar'),
                )),
            ] else
              Padding(
                padding:const EdgeInsets.only(top:6),
                child:Text('Sin 7 días de lecturas del sensor y 2 días '
                  'de entrenamiento completado no sugerimos un nivel '
                  'personalizado. Puedes elegirlo manualmente.',
                  key:const ValueKey('nutrition_activity_no_evidence'),
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:colors.onSurfaceVariant)),
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
            if(widget.mobileCompactLayout)
              Text('Objetivo: ${StkAgeAwareNutritionPlans.label(_stkGoal)}',style:Theme.of(context).textTheme.titleMedium)
            else DropdownButtonFormField<EnergyGoal>(
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
                if (value == null) return;
                _chooseStkGoal(switch (value) {
                  EnergyGoal.maintenance => StkNutritionIntent.maintenance,
                  EnergyGoal.gradualGain => StkNutritionIntent.volume,
                  EnergyGoal.gradualLoss => StkNutritionIntent.deficit,
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
}
