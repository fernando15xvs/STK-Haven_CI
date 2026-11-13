/// Keeps common durations and a custom selection, including values created
/// by extending a plan one week.
class ProgramDurationChoices {
  const ProgramDurationChoices._();

  static const recommendedWeeks = <int>[4, 6, 8, 10, 12, 16, 20, 24];

  static List<int> forSelected(int selected) {
    final choices = <int>{...recommendedWeeks, if (selected > 0) selected};
    return choices.toList()..sort();
  }

  /// Extends duration, not a deload week or a copied training microcycle.
  static int addWeek(int current) {
    if (current <= 0) throw ArgumentError.value(current, 'current');
    return current + 1;
  }
}
