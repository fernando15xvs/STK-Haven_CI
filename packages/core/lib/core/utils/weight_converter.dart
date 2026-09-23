import 'package:core/domain/models/settings_state.dart';

class WeightConverter {
  static const double _kgToLbRatio = 2.20462;

  static double convertKgToLb(double kg) {
    return kg * _kgToLbRatio;
  }

  static double convertLbToKg(double lb) {
    return lb / _kgToLbRatio;
  }

  static double displayWeight(double weightInKg, WeightUnit unit) {
    if (unit == WeightUnit.lb) {
      return convertKgToLb(weightInKg);
    }
    return weightInKg;
  }

  static String formatWeight(double weightInKg, WeightUnit unit) {
    final value = displayWeight(weightInKg, unit);
    // If it ends in .0, show it without decimal, otherwise 1 decimal point
    if (value % 1 == 0) {
      return '${value.toInt()} ${unit.label}';
    }
    return '${value.toStringAsFixed(1)} ${unit.label}';
  }

  /// Converts a value the user typed in their active [unit] to canonical kg
  /// for storage in Hive. This is the write-path counterpart of [displayWeight].
  ///
  /// Example: user types 100 lb → [toCanonicalKg(100, WeightUnit.lb)] → 45.359 kg
  static double toCanonicalKg(double displayValue, WeightUnit unit) {
    if (unit == WeightUnit.lb) return convertLbToKg(displayValue);
    return displayValue;
  }
}
