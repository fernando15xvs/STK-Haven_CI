part of 'nutrition_intelligence_page.dart';

mixin _NutritionFoodPresentation on _NutritionPageStateBase {
  @override
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
                        ?.copyWith(fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800)]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.mobileCompactLayout
                  ? 'Analiza tu comida con una foto.'
                  : _hasAdultNumericAccess
                      ? 'Toma o sube una foto. La IA devuelve rangos, ingredientes, '
                          'porciones y nivel de confianza.'
                  : _isDeclaredTeen
                      ? 'Desde los 15 años puedes fotografiar tus comidas: '
                          'la IA reconoce ingredientes y porciones. '
                          'Las cifras por plato para adolescentes necesitan '
                          'revisión adicional antes de habilitarse.'
                      : 'Toma o sube una foto. La IA identifica alimentos '
                          'y porciones sin cifras cuando el acceso numérico '
                          'adulto no está confirmado.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            if (!widget.mobileCompactLayout) ...[
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
            ] else
              const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (widget.cameraAvailable)
                  widget.mobileCompactLayout
                      ? FilledButton.icon(
                          key: const ValueKey('nutrition_mobile_take_photo'),
                          onPressed: _analyzing || _pickingPhoto
                              ? null
                              : () => _pickAndAnalyze(NutritionPhotoSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Tomar foto'),
                        )
                      : OutlinedButton.icon(
                          onPressed: _analyzing
                              ? null
                              : () => _pickAndAnalyze(NutritionPhotoSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Tomar foto'),
                        ),
                OutlinedButton.icon(
                  key: widget.mobileCompactLayout
                      ? const ValueKey('nutrition_mobile_choose_photo')
                      : null,
                  onPressed: _analyzing || (widget.mobileCompactLayout && _pickingPhoto)
                      ? null
                      : () => _pickAndAnalyze(NutritionPhotoSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir foto'),
                ),
                if (_photo != null && !widget.mobileCompactLayout)
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
              if (widget.mobileCompactLayout) ...[
                ExpansionTile(
                  key: const ValueKey('nutrition_mobile_photo_details'),
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: _showPhotoDetails,
                  onExpansionChanged: (value) => _showPhotoDetails = value,
                  title: const Text('Añadir detalles (opcional)'),
                  children: [
                    TextField(
                      controller: _dishHintController,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        hintText: 'Ej.: arroz, pollo y una cucharada de aceite',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('nutrition_mobile_analyze_photo'),
                      onPressed: _analyzing ? null : () => _analyzePhoto(photo),
                      icon: Icon(_foodEstimate == null
                          ? Icons.auto_awesome_outlined
                          : Icons.refresh_rounded),
                      label: Text(_foodEstimate == null
                          ? 'Analizar foto'
                          : 'Volver a analizar'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('nutrition_mobile_discard_photo'),
                      onPressed: () => setState(() {
                        _analysisEpoch++;
                        _photo = null;
                        _foodEstimate = null;
                        _analyzing = false;
                        _message = null;
                        _showPhotoDetails = false;
                      }),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Descartar'),
                    ),
                  ],
                ),
              ],
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.error),
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
}
