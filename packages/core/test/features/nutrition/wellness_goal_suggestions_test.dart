import 'package:core/features/nutrition/application/wellness_goal_suggestions.dart';
import 'package:test/test.dart';

void main(){
  test('seven recorded days required, never assumes missing days are zeros',(){
    expect(WellnessGoalSuggestions.stepsFromBaseline([3000,4000]),isNull);
    expect(WellnessGoalSuggestions.stepsFromBaseline([]),isNull);
  });
  test('robust typical activity, outliers do not dictate a 10k universal goal',(){
    final target=WellnessGoalSuggestions.stepsFromBaseline(
      [4200,4600,4400,4800,4500,4600,24000]);
    expect(target,4500);
  });
  test('no prescription for low baseline or unusable values',(){
    expect(WellnessGoalSuggestions.stepsFromBaseline(
      [0,0,0,0,0,0,0]),isNull);
    expect(WellnessGoalSuggestions.stepsFromBaseline(
      [-100,300000,1000,2000,3000,4000,5000]),isNull);
  });
}
