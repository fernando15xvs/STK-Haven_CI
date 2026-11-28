part of 'nutrition_intelligence_page.dart';

mixin _NutritionHistoryPresentation on _NutritionPageStateBase {
  @override
  Widget _buildHistory(ColorScheme colors) {
    final frequent=_historyRepository.frequentDishes();
    final content = Padding(
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
                        ?.copyWith(fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800)]),
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
            if(widget.mobileCompactLayout && _hasAdultNumericAccess)
              _buildConfirmedMeals(colors),
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
                    if (widget.mobileCompactLayout) _showMobileHistory = false;
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
                    PopupMenuButton<String>(
                      tooltip:'Opciones de análisis',
                      onSelected:(action){
                        if(action=='delete')_deleteHistoryEntry(entry.id);
                        if(action=='consumed')_setMealConsumption(entry);
                         if(action=='removeConsumption')_setMealConsumption(entry,remove:true);
                      },
                      itemBuilder:(_)=>[
                        if(widget.mobileCompactLayout && _hasAdultNumericAccess && entry.estimate.numericNutritionAvailable)
                          PopupMenuItem(value:'consumed',child:Text(entry.consumedAt==null?'Registrar comida consumida':'Editar porción consumida')),
                         if(widget.mobileCompactLayout && _hasAdultNumericAccess && entry.estimate.numericNutritionAvailable && entry.consumedAt!=null)
                           const PopupMenuItem(value:'removeConsumption',child:Text('Quitar registro de consumo')),
                        const PopupMenuItem(value:'delete',child:Text('Eliminar')),
                      ],
                    ),
                  ]),
                ),
          ],
        ),
      );
    if (widget.mobileCompactLayout) return content;
    return Card(child: content);
  }

  Widget _buildConfirmedMeals(ColorScheme colors) {
    final summary=FoodVisionDailySummary.forDay(_history,DateTime.now(),
      adultAuthorized:_hasAdultNumericAccess);
    String range(FoodVisionIntakeRange? value,String unit) => value==null
      ?'Sin estimación completa':'${value.low.floor()}–${value.high.ceil()} $unit';
    final plan=_activePlan;
    return Card(color:colors.surface,child:Padding(padding:const EdgeInsets.all(12),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Comidas confirmadas hoy',style:Theme.of(context).textTheme.titleMedium),
        Text('${summary.confirmedCount} registros voluntarios · historial parcial'),
        if(summary.confirmedCount>0) ...[
          const SizedBox(height:10),
          Text('Energía registrada · ${range(summary.energy,'kcal')}'),
          Text('Proteína · ${range(summary.protein,'g')}'),
          Text('Carbohidratos · ${range(summary.carbs,'g')}'),
          Text('Grasas · ${range(summary.fat,'g')}'),
          if(plan!=null && !plan.isPaused && plan.goal==_goal)
            Text('Plan guardado (referencia diaria): ${plan.estimate.targetLow}–${plan.estimate.targetHigh} kcal'),
          const SizedBox(height:8),
        ],
        const Text('Solo las porciones confirmadas se incluyen. Los rangos son aproximados y pueden faltar comidas o datos. No se calcula un saldo de calorías ni se ajusta el plan automáticamente.'),
      ])));
  }
}
