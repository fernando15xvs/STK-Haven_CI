/// Immutable projection of a server-controlled access response. Never
/// construct privileged values from a DOB, user_metadata, local Hive or
/// a JSON object saved by the device.
class StkNutritionServerCapabilities {
  const StkNutritionServerCapabilities({
    required this.personalizedAdultEnergy,
    required this.informationalFoodEstimate,
    required this.legalCurrent,
  });

  final bool personalizedAdultEnergy;
  final bool informationalFoodEstimate;
  final bool legalCurrent;

  /// Do not parse booleans from strings, numbers, missing keys or local flags.
  /// Null means unavailable/malformed, which callers must fail closed.
  static StkNutritionServerCapabilities? parse(Object? response) {
    if (response is! Map) return null;
    final adult = response['personalizedAdultEnergy'];
    final food = response['informationalFoodEstimate'];
    final legal = response['legalCurrent'];
    if (adult is! bool || food is! bool || legal is! bool) return null;
    // Contradictory server output cannot activate a capability.
    if ((adult || food) && !legal) return null;
    return StkNutritionServerCapabilities(
      personalizedAdultEnergy: adult,
      informationalFoodEstimate: food,
      legalCurrent: legal,
    );
  }
}
