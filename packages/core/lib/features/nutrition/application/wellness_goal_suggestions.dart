/// Non-medical, opt-in activity suggestions. Energy phase never prescribes
/// steps or water by itself, and no existing manual goal is overwritten here.
class WellnessGoalSuggestions {
  const WellnessGoalSuggestions._();

  /// Requires at least seven explicitly recorded days; no data is not zero.
  /// A median avoids overweighting one unusually active day.
  static int? stepsFromBaseline(Iterable<int> recordedDailySteps) {
    final values=recordedDailySteps
      .where((v)=>v>=0 && v<=250000).toList()..sort();
    if(values.length<7)return null;
    final median=values.length.isOdd?values[values.length~/2]:
      ((values[values.length~/2-1]+values[values.length~/2])/2).round();
    if(median<1000)return null;
    return ((median/500).round()*500).clamp(1000,20000).toInt();
  }
}
