import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('adult plan stores source dates and original ranges without recomputation',(){
    final plan=NutritionGoalPlan(
      savedAt:DateTime(2026,11,15),
      weightRecordId:'weight-measure',heightRecordId:'height-measure',
      weightRecordedAt:DateTime(2026,11,12),
      heightRecordedAt:DateTime(2026,10,1),
      weightKg:77,heightCm:178,ageYears:25,
      accessCheckedAt:DateTime.utc(2026,11,15,19,30),
      equationSex:EnergyEquationSex.male,
      activityLevel:EnergyActivityLevel.moderate,
      goal:EnergyGoal.gradualGain,
      estimate:const EnergyEstimate(maintenanceLow:2350,maintenanceHigh:2700,
        targetLow:2650,targetHigh:2800,referenceBmr:1700,
        goal:EnergyGoal.gradualGain,method:'Mifflin-St Jeor',
        assumptions:['Estimación']),
    );
    final restored=NutritionGoalPlan.fromJson(plan.toJson());
    expect(restored.weightRecordId,'weight-measure');
    expect(restored.heightRecordId,'height-measure');
    expect(restored.heightRecordedAt.month,10);
    expect(restored.estimate.targetHigh,2800);
    expect(restored.goal,EnergyGoal.gradualGain);
    expect(restored.formulaVersion,'mifflin_st_jeor_v1');
    expect(restored.accessCheckedAt,DateTime.utc(2026,11,15,19,30));
    expect(restored.toJson()['accessEvidence'],
      'stk_has_adult_nutrition_access');
    expect((restored.toJson()['units'] as Map)['weight'],'kg');
    expect((restored.toJson()['units'] as Map)['height'],'cm');
  });
  test('rejects incorrect snapshot units rather than converting twice',(){
    final plan=NutritionGoalPlan(
      savedAt:DateTime(2026,11,15),
      weightRecordId:'w',heightRecordId:'h',
      weightRecordedAt:DateTime(2026,11,12),
      heightRecordedAt:DateTime(2026,10,1),
      weightKg:70,heightCm:170,ageYears:25,
      equationSex:EnergyEquationSex.female,
      activityLevel:EnergyActivityLevel.light,
      goal:EnergyGoal.maintenance,
      estimate:const EnergyEstimate(
        maintenanceLow:1800,maintenanceHigh:2100,
        targetLow:1800,targetHigh:2100,referenceBmr:1500,
        goal:EnergyGoal.maintenance,method:'Mifflin-St Jeor',
        assumptions:[]),
    );
    final malformed=plan.toJson()
      ..['units']={'weight':'lb','height':'cm','energy':'kcal/day'};
    expect(()=>NutritionGoalPlan.fromJson(malformed),throwsFormatException);
  });

  test('rejects underage or incompatible saved targets',(){
    expect(()=>NutritionGoalPlan.fromJson({
      'version':1,'weightKg':55,'heightCm':165,'ageYears':15,
    }),throwsFormatException);
    expect(()=>NutritionGoalPlan.fromJson({'version':10}),throwsFormatException);
  });
}
