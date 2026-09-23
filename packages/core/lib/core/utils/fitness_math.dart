/// Central repository for fitness math formulas.
/// All inputs and outputs use canonical units (kg, reps).
class FitnessMath {
  FitnessMath._();

  /// Estimates 1-Rep Max using the Brzycki formula.
  ///
  /// Returns `null` when the parameters fall outside the valid domain:
  ///   - [weightKg] must be > 0
  ///   - [reps] must be in the range [1, 10]
  ///
  /// Callers no longer need to guard with `if (reps > 0 && reps <= 10)`.
  static double? estimated1RM(double weightKg, int reps) {
    if (weightKg <= 0 || reps <= 0 || reps > 10) return null;
    if (reps == 1) return weightKg; // 1RM exact for 1 rep
    return weightKg / (1.0278 - (0.0278 * reps));
  }

  /// Rounds [value] to the nearest 0.5.
  ///
  /// Intended for display of weights in kg (e.g., plate rounding).
  /// **Do NOT use this on progression increments that originated in lb**,
  /// as it destroys the precision of the canonical kg equivalent
  /// (e.g., 5 lb = 2.268 kg -> rounded to 2.5 kg != 5 lb).
  static double roundToNearestHalf(double value) {
    return (value * 2).roundToDouble() / 2.0;
  }
}
