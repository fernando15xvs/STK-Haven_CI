import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/adult_energy_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = AdultEnergyPlanner();

  group('AdultEnergyPlanner', () {
    test('returns an uncertainty range instead of a single target', () {
      final estimate = planner.calculate(
        const AdultEnergyProfile(
          ageYears: 30,
          heightCm: 170,
          weightKg: 70,
          equationSex: EnergyEquationSex.female,
          activityLevel: EnergyActivityLevel.moderate,
          goal: EnergyGoal.maintenance,
        ),
      );

      expect(estimate.maintenanceLow, lessThan(estimate.maintenanceHigh));
      expect(estimate.targetLow, estimate.maintenanceLow);
      expect(estimate.targetHigh, estimate.maintenanceHigh);
      expect(estimate.method, contains('Mifflin'));
    });

    test('gradual loss stays below estimated maintenance midpoint', () {
      final estimate = planner.calculate(
        const AdultEnergyProfile(
          ageYears: 32,
          heightCm: 178,
          weightKg: 82,
          equationSex: EnergyEquationSex.male,
          activityLevel: EnergyActivityLevel.light,
          goal: EnergyGoal.gradualLoss,
        ),
      );

      expect(estimate.targetHigh, lessThan(estimate.maintenanceMidpoint));
      expect(estimate.targetLow, lessThanOrEqualTo(estimate.targetHigh));
    });

    test('gradual gain stays above estimated maintenance midpoint', () {
      final estimate = planner.calculate(
        const AdultEnergyProfile(
          ageYears: 28,
          heightCm: 175,
          weightKg: 74,
          equationSex: EnergyEquationSex.male,
          activityLevel: EnergyActivityLevel.high,
          goal: EnergyGoal.gradualGain,
        ),
      );

      expect(estimate.targetLow, greaterThan(estimate.maintenanceMidpoint));
      expect(estimate.targetHigh, greaterThanOrEqualTo(estimate.targetLow));
    });

    test('rejects personalized calorie goals for minors', () {
      expect(
        () => planner.calculate(
          const AdultEnergyProfile(
            ageYears: 17,
            heightCm: 165,
            weightKg: 60,
            equationSex: EnergyEquationSex.female,
            activityLevel: EnergyActivityLevel.moderate,
            goal: EnergyGoal.gradualLoss,
          ),
        ),
        throwsA(isA<AdultEnergyPlanningException>()),
      );
    });
  });

  group('FoodVisionEstimate', () {
    test('parses ranges and uncertainty without requiring exact calories', () {
      final estimate = FoodVisionEstimate.fromJson({
        'dishName': 'Arroz con pollo',
        'items': [
          {
            'name': 'Arroz',
            'portionDescription': 'porción visible',
            'gramsLow': 140,
            'gramsHigh': 190,
            'caloriesLow': 180,
            'caloriesHigh': 260,
            'confidence': 'medium',
          }
        ],
        'caloriesLow': 480,
        'caloriesHigh': 650,
        'confidence': 'medium',
        'numericNutritionAvailable': true,
        'assumptions': ['No se conoce el aceite exacto.'],
        'questions': ['¿Se usó aceite adicional?'],
        'disclaimer': 'Estimación visual.',
      });

      expect(estimate.items, hasLength(1));
      expect(estimate.caloriesLow, 480);
      expect(estimate.caloriesHigh, 650);
      expect(estimate.confidence, FoodVisionConfidence.medium);
      expect(estimate.questions, isNotEmpty);
    });

    test('supports non-numeric result for users without adult access', () {
      final estimate = FoodVisionEstimate.fromJson({
        'dishName': 'Plato mixto',
        'items': const [],
        'confidence': 'low',
        'numericNutritionAvailable': false,
        'assumptions': const [],
        'questions': const [],
        'disclaimer': 'Sin estimación numérica.',
      });

      expect(estimate.numericNutritionAvailable, isFalse);
      expect(estimate.caloriesLow, isNull);
      expect(estimate.caloriesHigh, isNull);
    });
  });
}
