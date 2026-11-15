import 'package:core/domain/models/nutrition_intelligence.dart';

/// An adult's explicitly saved reference, never a medical prescription.
/// Snapshot values must not be silently rewritten when measurements change.
class NutritionGoalPlan {
  const NutritionGoalPlan({
    required this.savedAt,
    required this.weightRecordId,
    required this.heightRecordId,
    required this.weightRecordedAt,
    required this.heightRecordedAt,
    required this.weightKg,
    required this.heightCm,
    required this.ageYears,
    required this.equationSex,
    required this.activityLevel,
    required this.goal,
    required this.estimate,
    this.isPaused=false,
    this.nextReviewAt,
  });

  final DateTime savedAt;
  final String weightRecordId;
  final String heightRecordId;
  final DateTime weightRecordedAt;
  final DateTime heightRecordedAt;
  final double weightKg, heightCm;
  final int ageYears;
  final EnergyEquationSex equationSex;
  final EnergyActivityLevel activityLevel;
  final EnergyGoal goal;
  final EnergyEstimate estimate;
  /// A paused plan remains available as an archived reference, not a goal.
  final bool isPaused;
  /// A voluntary review date only; no automatic calorie adjustment/reminders.
  final DateTime? nextReviewAt;
  static const version=2;

  NutritionGoalPlan copyWith({
    bool? isPaused,
    DateTime? nextReviewAt,
    bool clearNextReview=false,
  })=>NutritionGoalPlan(
    savedAt:savedAt,weightRecordId:weightRecordId,
    heightRecordId:heightRecordId,
    weightRecordedAt:weightRecordedAt,
    heightRecordedAt:heightRecordedAt,
    weightKg:weightKg,heightCm:heightCm,ageYears:ageYears,
    equationSex:equationSex,activityLevel:activityLevel,goal:goal,
    estimate:estimate,
    isPaused:isPaused??this.isPaused,
    nextReviewAt:clearNextReview?null:(nextReviewAt??this.nextReviewAt),
  );

  Map<String,dynamic> toJson()=>{
    'version':version,
    'isPaused':isPaused,
    'nextReviewAt':nextReviewAt?.toIso8601String(),
    'savedAt':savedAt.toIso8601String(),
    'weightRecordId':weightRecordId,
    'heightRecordId':heightRecordId,
    'weightRecordedAt':weightRecordedAt.toIso8601String(),
    'heightRecordedAt':heightRecordedAt.toIso8601String(),
    'weightKg':weightKg,
    'heightCm':heightCm,
    'ageYears':ageYears,
    'equationSex':equationSex.name,
    'activityLevel':activityLevel.name,
    'goal':goal.name,
    'maintenanceLow':estimate.maintenanceLow,
    'maintenanceHigh':estimate.maintenanceHigh,
    'targetLow':estimate.targetLow,
    'targetHigh':estimate.targetHigh,
    'referenceBmr':estimate.referenceBmr,
    'method':estimate.method,
    'assumptions':estimate.assumptions,
  };

  factory NutritionGoalPlan.fromJson(Map<String,dynamic> json){
    if(json['version']!=1 && json['version']!=version){
      throw const FormatException('Plan versionado incompatible');
    }
    T pick<T extends Enum>(List<T> values,String key){
      return values.firstWhere((e)=>e.name==json[key],
        orElse:()=>throw const FormatException('Valor de plan inválido'));
    }
    final weight=(json['weightKg'] as num).toDouble();
    final height=(json['heightCm'] as num).toDouble();
    final age=(json['ageYears'] as num).toInt();
    if(!weight.isFinite||weight<35||weight>300||
       !height.isFinite||height<120||height>230||
       age<18||age>100)throw const FormatException('Medidas del plan inválidas');
    final estimate=EnergyEstimate(
      maintenanceLow:(json['maintenanceLow'] as num).round(),
      maintenanceHigh:(json['maintenanceHigh'] as num).round(),
      targetLow:(json['targetLow'] as num).round(),
      targetHigh:(json['targetHigh'] as num).round(),
      referenceBmr:(json['referenceBmr'] as num).round(),
      goal:pick(EnergyGoal.values,'goal'),
      method:json['method'] as String,
      assumptions:(json['assumptions'] as List).cast<String>(),
    );
    if(estimate.targetLow<=0||estimate.targetHigh<estimate.targetLow)
      throw const FormatException('Rango inválido');
    return NutritionGoalPlan(
      savedAt:DateTime.parse(json['savedAt'] as String),
      weightRecordId:json['weightRecordId'] as String,
      heightRecordId:json['heightRecordId'] as String,
      weightRecordedAt:DateTime.parse(json['weightRecordedAt'] as String),
      heightRecordedAt:DateTime.parse(json['heightRecordedAt'] as String),
      weightKg:weight,heightCm:height,ageYears:age,
      equationSex:pick(EnergyEquationSex.values,'equationSex'),
      activityLevel:pick(EnergyActivityLevel.values,'activityLevel'),
      goal:pick(EnergyGoal.values,'goal'),
      estimate:estimate,
      isPaused:json['isPaused']==true,
      nextReviewAt:DateTime.tryParse(json['nextReviewAt']?.toString()??''),
    );
  }
}
