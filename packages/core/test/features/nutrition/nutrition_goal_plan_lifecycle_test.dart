import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:test/test.dart';

void main(){
  NutritionGoalPlan plan()=>NutritionGoalPlan(
    savedAt:DateTime(2026,11,15),
    weightRecordId:'w-1',
    heightRecordId:'h-1',
    weightRecordedAt:DateTime(2026,11,14),
    heightRecordedAt:DateTime(2026,10,20),
    weightKg:72,heightCm:173,ageYears:27,
    equationSex:EnergyEquationSex.female,
    activityLevel:EnergyActivityLevel.moderate,
    goal:EnergyGoal.maintenance,
    estimate:const EnergyEstimate(
      maintenanceLow:2100,maintenanceHigh:2400,
      targetLow:2100,targetHigh:2400,
      referenceBmr:1460,goal:EnergyGoal.maintenance,
      method:'Mifflin–St Jeor',assumptions:['Estimación']),
  );

  test('pause does not alter estimated ranges or source measurements',(){
    final initial=plan();
    final paused=initial.copyWith(isPaused:true,
      nextReviewAt:DateTime(2026,12,12));
    final restored=NutritionGoalPlan.fromJson(paused.toJson());
    expect(restored.isPaused,isTrue);
    expect(restored.nextReviewAt,DateTime(2026,12,12));
    expect(restored.estimate.targetLow,2100);
    expect(restored.weightKg,72);
    expect(restored.heightRecordId,'h-1');
    expect(restored.savedAt,DateTime(2026,11,15));
    expect(restored.copyWith(isPaused:false).isPaused,isFalse);
    expect(restored.copyWith(clearNextReview:true).nextReviewAt,isNull);
  });

  test('v1 saved adults migrate to v3 without changing past ranges',(){
    final old=plan().toJson()
      ..remove('isPaused')..remove('nextReviewAt')
      ..remove('formulaVersion')..remove('units')
      ..remove('accessCheckedAt')..remove('accessEvidence');
    old['version']=1;
    final restored=NutritionGoalPlan.fromJson(old);
    expect(restored.isPaused,isFalse);
    expect(restored.nextReviewAt,isNull);
    expect(restored.weightKg,72);
    expect(restored.toJson()['version'],3);
    expect(restored.formulaVersion,'legacy_unspecified');
    expect(restored.accessCheckedAt,isNull);
  });

  test('v2 saved adults remain readable without inventing verification',(){
    final old=plan().toJson();
    old['version']=2;
    old.remove('formulaVersion');
    old.remove('units');
    old.remove('accessCheckedAt');
    old.remove('accessEvidence');
    final restored=NutritionGoalPlan.fromJson(old);
    expect(restored.weightRecordId,'w-1');
    expect(restored.estimate.targetLow,2100);
    expect(restored.formulaVersion,'legacy_unspecified');
    expect(restored.accessCheckedAt,isNull);
  });

  test('future incompatible plan versions remain rejected',(){
    expect(()=>NutritionGoalPlan.fromJson({
      ...plan().toJson(),
      'version':4,
    }),throwsFormatException);
  });
}
