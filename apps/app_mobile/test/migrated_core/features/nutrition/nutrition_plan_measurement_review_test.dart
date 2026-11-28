import 'dart:io';
import '../../../support/nutrition_page_source.dart';

import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/nutrition_goal_plan.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/latest_body_measurements.dart';
import 'package:core/features/nutrition/application/nutrition_plan_measurement_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NutritionGoalPlan saved()=>NutritionGoalPlan(
    savedAt:DateTime(2026,11,15),
    weightRecordId:'weight',heightRecordId:'height',
    weightRecordedAt:DateTime(2026,11,10),
    heightRecordedAt:DateTime(2026,10,20),
    weightKg:72,heightCm:173,ageYears:27,
    equationSex:EnergyEquationSex.female,
    activityLevel:EnergyActivityLevel.moderate,
    goal:EnergyGoal.maintenance,
    estimate:const EnergyEstimate(
      maintenanceLow:2100,maintenanceHigh:2400,
      targetLow:2100,targetHigh:2400,
      referenceBmr:1460,goal:EnergyGoal.maintenance,
      method:'Mifflin-St Jeor',assumptions:['Estimación']),
  );

  List<BodyMeasurement> source()=>[
    BodyMeasurement(id:'weight',date:DateTime(2026,11,10),
      weightKg:72),
    BodyMeasurement(id:'height',date:DateTime(2026,10,20),
      heightCm:173),
  ];

  test('unchanged real sources need no extra calculator action',(){
    final review=NutritionPlanMeasurementReview.compare(
      saved(),LatestBodyMeasurements.fromRecords(source()));
    expect(review.needsReview,isFalse);
    expect(review.canRecalculate,isTrue);
  });

  test('more recent weight requires review without changing old plan',(){
    final plan=saved();
    final current=LatestBodyMeasurements.fromRecords([
      ...source(),
      BodyMeasurement(id:'new-weight',date:DateTime(2026,11,16),
        weightKg:71.5),
    ]);
    final review=NutritionPlanMeasurementReview.compare(plan,current);
    expect(review.weightChanged,isTrue);
    expect(review.heightChanged,isFalse);
    expect(review.canRecalculate,isTrue);
    expect(plan.weightKg,72);
    expect(plan.estimate.targetLow,2100);
  });

  test('editing the same record ID is detectable by its value or date',(){
    final current=LatestBodyMeasurements.fromRecords([
      BodyMeasurement(id:'weight',date:DateTime(2026,11,10),
        weightKg:73),
      BodyMeasurement(id:'height',date:DateTime(2026,11,1),
        heightCm:173),
    ]);
    final review=NutritionPlanMeasurementReview.compare(saved(),current);
    expect(review.weightChanged,isTrue);
    expect(review.heightChanged,isTrue);
  });

  test('deleting a required record prompts Medidas, not fake recalc',(){
    final current=LatestBodyMeasurements.fromRecords([
      BodyMeasurement(id:'weight',date:DateTime(2026,11,10),
        weightKg:72),
    ]);
    final review=NutritionPlanMeasurementReview.compare(saved(),current);
    expect(review.needsReview,isTrue);
    expect(review.canRecalculate,isFalse);
    expect(review.hasMissingData,isTrue);
  });

  test('UI requires explicit recalc and keeps historical plan snapshot',(){
    final code=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(code,contains('NutritionPlanMeasurementReview.compare('));
    expect(code,contains("ValueKey('nutrition_review_changed_measures')"));
    expect(code,contains('void _preparePlanReview(NutritionGoalPlan plan)'));
    expect(code,contains('_invalidateEnergyDraft();'));
    expect(code,contains('Scrollable.ensureVisible(target'));
    expect(code,contains('El plan guardado se conserva sin cambios.'));
  });
}
