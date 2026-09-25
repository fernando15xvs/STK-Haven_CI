import 'dart:math' as math;

import 'package:core/domain/models/nutrition_intelligence.dart';

class AdultEnergyPlanner {
  const AdultEnergyPlanner();

  EnergyEstimate calculate(AdultEnergyProfile profile) {
    _validate(profile);

    final base = (10 * profile.weightKg) +
        (6.25 * profile.heightCm) -
        (5 * profile.ageYears) +
        (profile.equationSex == EnergyEquationSex.male ? 5 : -161);

    final maintenance = base * _activityFactor(profile.activityLevel);

    // Energy expenditure equations are estimates, so the product exposes a
    // range instead of presenting one number as physiological truth.
    final maintenanceLow = _round25(maintenance * 0.92);
    final maintenanceHigh = _round25(maintenance * 1.08);

    final (targetLowFactor, targetHighFactor) = switch (profile.goal) {
      EnergyGoal.maintenance => (0.92, 1.08),
      // Only modest adult adjustments are supported. More aggressive targets
      // intentionally remain outside this consumer feature.
      EnergyGoal.gradualLoss => (0.90, 0.95),
      EnergyGoal.gradualGain => (1.05, 1.10),
    };

    final targetLow = profile.goal == EnergyGoal.maintenance
        ? maintenanceLow
        : _round25(maintenance * targetLowFactor);
    final targetHigh = profile.goal == EnergyGoal.maintenance
        ? maintenanceHigh
        : _round25(maintenance * targetHighFactor);

    return EnergyEstimate(
      maintenanceLow: math.min(maintenanceLow, maintenanceHigh),
      maintenanceHigh: math.max(maintenanceLow, maintenanceHigh),
      targetLow: math.min(targetLow, targetHigh),
      targetHigh: math.max(targetLow, targetHigh),
      referenceBmr: _round25(base),
      goal: profile.goal,
      method: 'Mifflin-St Jeor + rango de incertidumbre',
      assumptions: const <String>[
        'Solo para adultos de 18 años o más.',
        'Es una estimación de referencia, no una prescripción médica.',
        'El gasto real cambia con sueño, actividad, entrenamiento y contexto.',
        'Los ajustes de objetivo son deliberadamente graduales.',
      ],
    );
  }

  void _validate(AdultEnergyProfile profile) {
    if (!profile.isAdult) {
      throw const AdultEnergyPlanningException(
        'Los objetivos calóricos personalizados están deshabilitados para menores de 18 años.',
      );
    }
    if (profile.ageYears > 100) {
      throw const AdultEnergyPlanningException('Edad fuera de rango.');
    }
    if (profile.heightCm < 120 || profile.heightCm > 230) {
      throw const AdultEnergyPlanningException('Estatura fuera de rango.');
    }
    if (profile.weightKg < 35 || profile.weightKg > 300) {
      throw const AdultEnergyPlanningException('Peso fuera de rango.');
    }
  }

  double _activityFactor(EnergyActivityLevel level) {
    return switch (level) {
      EnergyActivityLevel.sedentary => 1.20,
      EnergyActivityLevel.light => 1.35,
      EnergyActivityLevel.moderate => 1.50,
      EnergyActivityLevel.high => 1.70,
      EnergyActivityLevel.veryHigh => 1.85,
    };
  }

  int _round25(double value) => (value / 25).round() * 25;
}

class AdultEnergyPlanningException implements Exception {
  final String message;

  const AdultEnergyPlanningException(this.message);

  @override
  String toString() => message;
}
