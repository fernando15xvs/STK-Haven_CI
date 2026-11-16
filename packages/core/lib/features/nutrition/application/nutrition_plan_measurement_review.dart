import 'package:core/domain/models/nutrition_goal_plan.dart';

import 'latest_body_measurements.dart';

/// Compares a saved adult plan's original measurements with the latest valid
/// records already stored in Medidas. This never mutates or recalculates a plan.
class NutritionPlanMeasurementReview {
  const NutritionPlanMeasurementReview({
    required this.weightChanged,
    required this.heightChanged,
    required this.canRecalculate,
  });

  final bool weightChanged;
  final bool heightChanged;
  final bool canRecalculate;

  bool get needsReview=>weightChanged||heightChanged;
  bool get hasMissingData=>!canRecalculate;

  factory NutritionPlanMeasurementReview.compare(
    NutritionGoalPlan plan,
    LatestBodyMeasurements current,
  ) {
    final weight=current.weightKg;
    final height=current.heightCm;
    return NutritionPlanMeasurementReview(
      weightChanged:weight==null ||
        weight.recordId!=plan.weightRecordId ||
        !weight.recordedAt.isAtSameMomentAs(plan.weightRecordedAt) ||
        weight.value!=plan.weightKg,
      heightChanged:height==null ||
        height.recordId!=plan.heightRecordId ||
        !height.recordedAt.isAtSameMomentAs(plan.heightRecordedAt) ||
        height.value!=plan.heightCm,
      canRecalculate:current.canEstimateEnergy,
    );
  }
}
