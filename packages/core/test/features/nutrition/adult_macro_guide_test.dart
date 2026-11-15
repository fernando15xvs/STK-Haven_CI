import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/adult_macro_guide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main(){
  const reference=EnergyEstimate(
    maintenanceLow:2200,maintenanceHigh:2500,
    targetLow:2200,targetHigh:2500,
    referenceBmr:1650,goal:EnergyGoal.maintenance,
    method:'Mifflin-St Jeor',assumptions:['Estimación'],
  );

  test('broad AMDR percentages are preserved, not a fixed meal plan',(){
    expect(AdultMacroGuide.proteinPercentLow,10);
    expect(AdultMacroGuide.proteinPercentHigh,35);
    expect(AdultMacroGuide.carbsPercentLow,45);
    expect(AdultMacroGuide.carbsPercentHigh,65);
    expect(AdultMacroGuide.fatPercentLow,20);
    expect(AdultMacroGuide.fatPercentHigh,35);
    final result=AdultMacroGuide.fromEnergyEstimate(reference);
    expect(result.proteinGramsLow,55);
    expect(result.proteinGramsHigh,220);
    expect(result.carbsGramsLow,250);
    expect(result.carbsGramsHigh,405);
    expect(result.fatGramsLow,50);
    expect(result.fatGramsHigh,95);
  });

  test('invalid numeric energy intervals have no macro output',(){
    expect(()=>AdultMacroGuide.fromEnergyEstimate(const EnergyEstimate(
      maintenanceLow:2200,maintenanceHigh:2500,
      targetLow:0,targetHigh:2500,
      referenceBmr:1650,goal:EnergyGoal.maintenance,
      method:'x',assumptions:[],
    )),throwsFormatException);
  });

  test('UI requires 19+, backend grant and explicit user action',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains("ValueKey('nutrition_adult_macro_guide')"));
    expect(source,contains('if(age==null || age<19 || !_hasAdultNumericAccess)'));
    expect(source,contains('hasVerifiedAccess()'));
    expect(source,contains('No se guardan ni se aplican como dieta'));
    expect(source,contains('Los intervalos son independientes'));
  });
}
