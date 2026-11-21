import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/adult_energy_planner.dart';
import 'package:flutter/material.dart';

/// Compile-time, opt-in preview for internal QA only. Never an entitlement.
class NutritionInternalDemoConfig {
  const NutritionInternalDemoConfig._();

  static const bool enabled = bool.fromEnvironment(
    'STK_INTERNAL_NUTRITION_DEMO',
    defaultValue: false,
  );
}

/// This page is deliberately disconnected from Supabase, Hive, photos,
/// account identity and the real nutrition planner. All values are synthetic.
class NutritionInternalDemoPage extends StatefulWidget {
  const NutritionInternalDemoPage({super.key});

  @override
  State<NutritionInternalDemoPage> createState() =>
      _NutritionInternalDemoPageState();
}

class _NutritionInternalDemoPageState extends State<NutritionInternalDemoPage> {
  bool _adultExample = true;
  EnergyGoal _goal = EnergyGoal.maintenance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estimate = _adultExample
        ? const AdultEnergyPlanner().calculate(AdultEnergyProfile(
            ageYears: 25,
            heightCm: 175,
            weightKg: 70,
            equationSex: EnergyEquationSex.male,
            activityLevel: EnergyActivityLevel.moderate,
            goal: _goal,
          ))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Laboratorio de Nutrición')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIMULACIÓN · DATOS FICTICIOS',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    const Text(
                      'Este laboratorio sirve para probar la interfaz. '
                      'No utiliza tu edad, peso, historial ni cuenta. '
                      'No consulta servidores, no analiza fotografías '
                      'y no guarda ningún plan.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El acceso real sigue sujeto a las autorizaciones '
                      'de Nutrición. Esta vista no las modifica.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Elegir caso de prueba', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const ValueKey('nutrition_demo_adult'),
                  label: const Text('18+ de prueba'),
                  selected: _adultExample,
                  onSelected: (_) => setState(() => _adultExample = true),
                ),
                ChoiceChip(
                  key: const ValueKey('nutrition_demo_teen'),
                  label: const Text('15–17 de prueba'),
                  selected: !_adultExample,
                  onSelected: (_) => setState(() => _adultExample = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (estimate case final result?) ...[
              const Text(
                'Perfil sintético: 25 años, 70 kg, 175 cm, '
                'ecuación masculina y actividad moderada.',
              ),
              const SizedBox(height: 16),
              Text('Objetivo de demostración',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final goal in EnergyGoal.values)
                    ChoiceChip(
                      key: ValueKey('nutrition_demo_goal_'+goal.name),
                      label: Text(switch (goal) {
                        EnergyGoal.maintenance => 'Mantenimiento',
                        EnergyGoal.gradualGain => 'Volumen',
                        EnergyGoal.gradualLoss => 'Déficit',
                      }),
                      selected: _goal == goal,
                      onSelected: (_) => setState(() => _goal = goal),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimación para el ejemplo',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        result.targetLow.toString()+'–'+
                        result.targetHigh.toString()+' kcal/día',
                        key: const ValueKey('nutrition_demo_target'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text('Mantenimiento estimado: '+
                          result.maintenanceLow.toString()+'–'+
                          result.maintenanceHigh.toString()+' kcal/día'),
                      const SizedBox(height: 6),
                      const Text(
                        'Valores simulados: no son una recomendación '
                        'para tu cuerpo ni se pueden guardar.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Food Vision · ejemplo estático',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text('Arroz, pollo y verduras.'),
                      const SizedBox(height: 6),
                      const Text('Rango ilustrativo ficticio: 550–700 '
                          'kcal por plato. No procede de IA ni de una foto.'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nutrición para adolescentes',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Priorizar comidas variadas, recuperación, '
                        'hidratación y crecimiento. Las metas '
                        'automáticas restrictivas están desactivadas.',
                      ),
                      const SizedBox(height: 12),
                      Text('Food Vision · ejemplo descriptivo',
                          style: theme.textTheme.titleSmall),
                      const Text(
                        'Plato de ejemplo: arroz, pollo y verduras. '
                        'Se identifican alimentos sin asignar '
                        'objetivos numéricos.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
