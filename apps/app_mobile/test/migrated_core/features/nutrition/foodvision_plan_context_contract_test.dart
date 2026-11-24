import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('food and adult plan context is opt-in, never a calorie ledger',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains("ValueKey('foodvision_plan_context')"));
    expect(source,contains('_hasAdultNumericAccess && _activePlan!=null'));
    expect(source,contains('!_activePlan!.isPaused'));
    expect(source,contains('!estimate.numericNutritionAvailable'));
    expect(source,contains('Future<void> _showFoodPlanContext('));
    expect(source,contains('No se añadirá esta comida a un contador diario'));
    expect(source,contains('ni se descontarán calorías del plan'));
    expect(source,contains("onPressed:()=>_showFoodPlanContext(estimate)"));
  });
}
