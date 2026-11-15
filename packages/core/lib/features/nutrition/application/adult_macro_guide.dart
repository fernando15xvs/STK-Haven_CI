import 'package:core/domain/models/nutrition_intelligence.dart';

/// General Acceptable Macronutrient Distribution Ranges for apparently
/// healthy adults (19+) published by the National Academies / Health Canada.
/// These are independent ranges, NOT a fixed macro prescription or a diet.
/// Ref: https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-macronutrients.html
class AdultMacroGuide {
  const AdultMacroGuide({
    required this.proteinGramsLow,
    required this.proteinGramsHigh,
    required this.carbsGramsLow,
    required this.carbsGramsHigh,
    required this.fatGramsLow,
    required this.fatGramsHigh,
  });

  final int proteinGramsLow, proteinGramsHigh;
  final int carbsGramsLow, carbsGramsHigh;
  final int fatGramsLow, fatGramsHigh;

  static const proteinPercentLow=10;
  static const proteinPercentHigh=35;
  static const carbsPercentLow=45;
  static const carbsPercentHigh=65;
  static const fatPercentLow=20;
  static const fatPercentHigh=35;

  static int _nearestFive(double grams)=>(grams/5).round()*5;

  /// Converts each independent AMDR percentage range to approximate grams
  /// using an adult's EXISTING estimated energy interval. The output must
  /// never be summed across upper bounds to claim a 100% diet.
  factory AdultMacroGuide.fromEnergyEstimate(EnergyEstimate estimate) {
    final low=estimate.targetLow;
    final high=estimate.targetHigh;
    if(low<=0 || high<low || high>10000) {
      throw const FormatException('Rango de energía no válido');
    }
    int g(int kcal,int percent,int kcalPerGram)=>
      _nearestFive(kcal*(percent/100)/kcalPerGram);
    return AdultMacroGuide(
      proteinGramsLow:g(low,proteinPercentLow,4),
      proteinGramsHigh:g(high,proteinPercentHigh,4),
      carbsGramsLow:g(low,carbsPercentLow,4),
      carbsGramsHigh:g(high,carbsPercentHigh,4),
      fatGramsLow:g(low,fatPercentLow,9),
      fatGramsHigh:g(high,fatPercentHigh,9),
    );
  }
}
