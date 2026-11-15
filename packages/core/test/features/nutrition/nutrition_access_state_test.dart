import 'package:core/features/nutrition/application/nutrition_access_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('unknown age stays descriptive without verified backend grant',(){
    final state=NutritionAccessPolicy.resolve(
      declaredAge:null,backendVerifiedAdult:false);
    expect(state,NutritionAccessState.ageUnknown);
    expect(state.canViewNumericNutrition,isFalse);
  });

  test('birth date alone cannot grant calories to an unverified adult',(){
    final state=NutritionAccessPolicy.resolve(
      declaredAge:32,backendVerifiedAdult:false);
    expect(state,NutritionAccessState.adultUnverified);
    expect(state.canViewNumericNutrition,isFalse);
  });

  test('declared minor is safer even with a stale old remote grant',(){
    final state=NutritionAccessPolicy.resolve(
      declaredAge:16,backendVerifiedAdult:true);
    expect(state,NutritionAccessState.minor);
    expect(state.isMinor,isTrue);
    expect(state.canViewNumericNutrition,isFalse);
  });

  test('only a verified server-side grant enables adult numeric estimates',(){
    final verified=NutritionAccessPolicy.resolve(
      declaredAge:24,backendVerifiedAdult:true);
    expect(verified,NutritionAccessState.adultVerified);
    expect(verified.canViewNumericNutrition,isTrue);
    final verifiedWithoutDob=NutritionAccessPolicy.resolve(
      declaredAge:null,backendVerifiedAdult:true);
    expect(verifiedWithoutDob,NutritionAccessState.adultVerified);
  });

  test('no local demographic input is ever proof of verification',(){
    for(final years in [18,25,65,95]){
      expect(NutritionAccessPolicy.resolve(
        declaredAge:years,backendVerifiedAdult:false)
        .canViewNumericNutrition,isFalse);
    }
  });
}
