import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/food_vision_daily_summary.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026,11,27,18);
  NutritionHistoryEntry meal(String id, {DateTime? at, double? portion=1,
    bool numeric=true, bool missingProtein=false}) => NutritionHistoryEntry(
    id:id, analyzedAt:DateTime(2026,11,26), dishHint:'',
    consumedAt:at, consumedFraction:portion,
    estimate:FoodVisionEstimate(dishName:'Plato',items:const [],
      confidence:FoodVisionConfidence.medium,numericNutritionAvailable:numeric,
      caloriesLow:400,caloriesHigh:600,proteinGramsLow:missingProtein?null:20,
      proteinGramsHigh:30,carbsGramsLow:30,carbsGramsHigh:40,
      fatGramsLow:10,fatGramsHigh:15,disclaimer:'Estimación'));
  test('only explicit today portions, no duplicate or future rows',(){
    final a=meal('a',at:DateTime(2026,11,27,10),portion:0.5);
    final result=FoodVisionDailySummary.forDay([
      a,a,meal('b',at:DateTime(2026,11,27,12),portion:0.25),
      meal('unconfirmed'),meal('yesterday',at:DateTime(2026,11,26)),
      meal('future',at:DateTime(2026,11,27,19)),
      meal('descriptive',at:now,numeric:false),
    ],now,adultAuthorized:true);
    expect(result.confirmedCount,2);
    expect(result.energy!.low,300);
    expect(result.energy!.high,450);
    expect(result.protein!.low,15);
    expect(result.protein!.high,22.5);
  });
  test('missing or invalid fields never become zero or fake totals',(){
    final result=FoodVisionDailySummary.forDay([
      meal('a',at:now,missingProtein:true),meal('b',at:now),
    ],now,adultAuthorized:true);
    expect(result.energy!.low,800);
    expect(result.protein,isNull);
    final invalid=FoodVisionDailySummary.forDay([
      meal('invalid',at:now,portion:double.nan),
    ],now,adultAuthorized:true);
    expect(invalid.energy,isNull);
  });
  test('revoked access returns no numbers or count',(){
    final result=FoodVisionDailySummary.forDay([meal('a',at:now)],now,
      adultAuthorized:false);
    expect(result.confirmedCount,0);
    expect(result.energy,isNull);
    expect(result.protein,isNull);
  });
  test('legacy full confirmation and fraction JSON are compatible',(){
    final raw=meal('a',at:now).toJson()..remove('consumedFraction');
    expect(NutritionHistoryEntry.fromJson(raw).consumedFraction,1);
    final partial=meal('b',at:now,portion:0.25);
    expect(NutritionHistoryEntry.fromJson(partial.toJson()).consumedFraction,0.25);
    expect(NutritionHistoryEntry.fromJson(partial.toJson()..['consumedFraction']=2).consumedFraction,isNull);
    expect(partial.copyWith(clearConsumption:true).consumedAt,isNull);
  });
}
