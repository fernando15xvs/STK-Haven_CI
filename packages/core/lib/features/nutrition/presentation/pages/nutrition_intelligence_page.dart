import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/adult_energy_planner.dart';
import 'package:core/features/nutrition/data/food_vision_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NutritionPhotoSource { camera, gallery }

typedef NutritionPhotoPicker = Future<NutritionPhoto?> Function(
  NutritionPhotoSource source,
);

class NutritionIntelligencePage extends StatefulWidget {
  final NutritionPhotoPicker photoPicker;
  final bool cameraAvailable;
  final bool verifiedAdultNutritionAccess;

  const NutritionIntelligencePage({
    super.key,
    required this.photoPicker,
    this.cameraAvailable = true,
    this.verifiedAdultNutritionAccess = false,
  });

  @override
  State<NutritionIntelligencePage> createState() =>
      _NutritionIntelligencePageState();
}

class _NutritionIntelligencePageState
    extends State<NutritionIntelligencePage> {
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '70');
  final _dishHintController = TextEditingController();

  EnergyEquationSex _equationSex = EnergyEquationSex.female;
  EnergyActivityLevel _activity = EnergyActivityLevel.moderate;
  EnergyGoal _goal = EnergyGoal.maintenance;
  EnergyEstimate? _energyEstimate;

  NutritionPhoto? _photo;
  FoodVisionEstimate? _foodEstimate;
  bool _analyzing = false;
  String? _message;

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dishHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Inteligente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            _HeroCard(colors: colors),
            const SizedBox(height: 16),
            if (!widget.verifiedAdultNutritionAccess)
              _AdultGateCard(colors: colors)
            else
              _buildEnergyPlanner(colors),
            const SizedBox(height: 16),
            _buildFoodVision(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyPlanner(ColorScheme colors) {
    return Card(
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
                    decoration: const InputDecoration(labelText: 'Edad'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Estatura (cm)'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyEquationSex>(
              value: _equationSex,
              decoration: const InputDecoration(
                labelText: 'Sexo usado por la ecuación',
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
                if (value != null) setState(() => _equationSex = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EnergyActivityLevel>(
              value: _activity,
              decoration: const InputDecoration(labelText: 'Actividad habitual'),
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
                if (value != null) setState(() => _activity = value);
              },
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
                if (value != null) setState(() => _goal = value);
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFoodVision(ColorScheme colors) {
    return Card(
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
              widget.verifiedAdultNutritionAccess
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
            if (_foodEstimate case final estimate?) ...[
              const SizedBox(height: 16),
              _FoodVisionResultCard(estimate: estimate),
            ],
          ],
        ),
      ),
    );
  }

  void _calculateEnergy() {
    try {
      final age = int.parse(_ageController.text.trim());
      final height =
          double.parse(_heightController.text.trim().replaceAll(',', '.'));
      final weight =
          double.parse(_weightController.text.trim().replaceAll(',', '.'));
      final estimate = const AdultEnergyPlanner().calculate(
        AdultEnergyProfile(
          ageYears: age,
          heightCm: height,
          weightKg: weight,
          equationSex: _equationSex,
          activityLevel: _activity,
          goal: _goal,
        ),
      );
      setState(() {
        _energyEstimate = estimate;
        _message = null;
      });
    } catch (error) {
      setState(() {
        _energyEstimate = null;
        _message = error.toString();
      });
    }
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
    setState(() {
      _foodEstimate = null;
      _message = null;
      _analyzing = true;
    });

    try {
      final estimate = await FoodVisionService(Supabase.instance.client).analyze(
        imageBytes: photo.bytes,
        mimeType: photo.mimeType,
        adultNumericNutrition: widget.verifiedAdultNutritionAccess,
        dishHint: _dishHintController.text,
      );
      if (!mounted) return;
      setState(() => _foodEstimate = estimate);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restaurant_menu_rounded, color: colors.onPrimaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registra con contexto, no con falsa precisión',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Las fotos no permiten conocer con exactitud aceite, salsas ni '
                  'gramajes. STK Haven muestra rangos, confianza y preguntas para '
                  'que el usuario pueda corregir la estimación.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdultGateCard extends StatelessWidget {
  const _AdultGateCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objetivos calóricos: acceso adulto verificado',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'El motor ya está preparado, pero no se habilita con una '
                    'autodeclaración. Antes del release debe conectarse a un gate '
                    'de edad real de la cuenta. Food Vision sigue funcionando en '
                    'modo descriptivo sin calorías/macros numéricos.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
