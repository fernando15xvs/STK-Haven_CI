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
  });
  test('rejects underage or incompatible saved targets',(){
    expect(()=>NutritionGoalPlan.fromJson({
      'version':1,'weightKg':55,'heightCm':165,'ageYears':15,
    }),throwsFormatException);
    expect(()=>NutritionGoalPlan.fromJson({'version':10}),throwsFormatException);
  });
}
