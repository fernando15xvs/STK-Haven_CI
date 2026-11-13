/// A restored backup may contain a custom rest interval in 0–600s.
/// Preserve it in the picker instead of throwing or rewriting the setting.
class UnilateralRestChoices {
  const UnilateralRestChoices._();

  static const recommended = <int>[0, 30, 45, 60, 90, 120, 180];

  static List<int> forSelected(int currentSeconds) {
    final values = <int>{
      ...recommended,
      currentSeconds.clamp(0, 600).toInt(),
    };
    return values.toList()..sort();
  }
}
