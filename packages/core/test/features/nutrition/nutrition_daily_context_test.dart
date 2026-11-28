import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/nutrition/application/adult_energy_planner.dart';
import 'package:core/features/nutrition/application/nutrition_daily_context.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:test/test.dart';

void main() {
  test('weight review needs distinct real days in both windows',(){
    final now=DateTime(2026,11,27,12);
    final records=[
      for(final d in [15,16,17,22,23,24]) BodyMeasurement(id:'w$d',
        date:DateTime(2026,11,d,9),weightKg:d<20?80:81),
      BodyMeasurement(id:'edit',date:DateTime(2026,11,22,10),weightKg:81),
    ];
    final value=NutritionDailyContext.weightReview(records,now)!;
    expect(value.earlier,80);
    expect(value.recent,81);
    expect(value.recentDays,3);
    expect(NutritionDailyContext.weightReview(records.take(2),now),isNull);
  });
  test('example is coherent with the energy range and refuses under 19', () {
    for(final goal in EnergyGoal.values) {
      final profile=AdultEnergyProfile(ageYears:25,weightKg:85,heightCm:175,
        equationSex:EnergyEquationSex.male,activityLevel:EnergyActivityLevel.moderate,goal:goal);
      final estimate=const AdultEnergyPlanner().calculate(profile);
      final example=TrainingMacroExample.calculate(profile,estimate)!;
      expect(example.energy,inInclusiveRange(estimate.targetLow,estimate.targetHigh));
      expect(example.proteinG*4/example.energy,inInclusiveRange(.10,.35));
      expect(example.carbsG*4/example.energy,inInclusiveRange(.45,.65));
      expect(example.fatG*9/example.energy,inInclusiveRange(.20,.35));
    }
    final teen=AdultEnergyProfile(ageYears:18,weightKg:70,heightCm:175,
      equationSex:EnergyEquationSex.male,activityLevel:EnergyActivityLevel.moderate,
      goal:EnergyGoal.maintenance);
    expect(TrainingMacroExample.calculate(teen,const AdultEnergyPlanner().calculate(teen)),isNull);
  });
  test('missing sleep is not fatigue and short sleep never suggests compensation', () {
    final now=DateTime(2026,11,27);
    String advice(SleepDiary diary)=>NutritionDailyContext.guidance(
      intent:StkNutritionIntent.deficit,adultAuthorized:true,now:now,
      sleep:diary,trainingCompleted:true);
    expect(advice(SleepDiary.empty()),contains('Conserva'));
    expect(advice(SleepDiary.empty().withEntry(now,240)),contains('Prioriza descanso'));
    expect(NutritionDailyContext.guidance(intent:StkNutritionIntent.deficit,
      adultAuthorized:false,now:now,sleep:SleepDiary.empty(),
      trainingCompleted:true),contains('Comidas variadas'));
  });
}
