import 'package:core/domain/models/nutrition_history_entry.dart';

/// Approximate ranges, never a prescription or a complete dietary record.
class FoodVisionIntakeRange {
  final double low;
  final double high;
  const FoodVisionIntakeRange(this.low, this.high);
}

class FoodVisionDailySummary {
  final int confirmedCount;
  final FoodVisionIntakeRange? energy, protein, carbs, fat;
  const FoodVisionDailySummary._(this.confirmedCount, this.energy,
      this.protein, this.carbs, this.fat);

  factory FoodVisionDailySummary.forDay(
    Iterable<NutritionHistoryEntry> entries, DateTime now, {
    required bool adultAuthorized,
  }) {
    if (!adultAuthorized) {
      return const FoodVisionDailySummary._(0, null, null, null, null);
    }
    final day = now.toLocal();
    final seen = <String>{};
    final rows = <NutritionHistoryEntry>[];
    for (final entry in entries) {
      final date = entry.consumedAt?.toLocal();
      if (date == null || date.isAfter(day) ||
          date.year != day.year || date.month != day.month ||
          date.day != day.day || !entry.estimate.numericNutritionAvailable ||
          entry.id.trim().isEmpty || !seen.add(entry.id)) {
        continue;
      }
      rows.add(entry);
    }
    FoodVisionIntakeRange? sum(
      num? Function(NutritionHistoryEntry) lower,
      num? Function(NutritionHistoryEntry) upper,
    ) {
      if (rows.isEmpty) return null;
      var low = 0.0;
      var high = 0.0;
      for (final row in rows) {
        final l = lower(row);
        final h = upper(row);
        final fraction = row.consumedFraction;
        if (fraction == null || !NutritionHistoryEntry.validFraction(fraction) ||
            l == null || h == null || !l.isFinite || !h.isFinite ||
            l < 0 || h < l) return null;
        low += l * fraction;
        high += h * fraction;
      }
      if (!low.isFinite || !high.isFinite) return null;
      return FoodVisionIntakeRange(low, high);
    }
    return FoodVisionDailySummary._(
      rows.length,
      sum((r) => r.estimate.caloriesLow, (r) => r.estimate.caloriesHigh),
      sum((r) => r.estimate.proteinGramsLow, (r) => r.estimate.proteinGramsHigh),
      sum((r) => r.estimate.carbsGramsLow, (r) => r.estimate.carbsGramsHigh),
      sum((r) => r.estimate.fatGramsLow, (r) => r.estimate.fatGramsHigh),
    );
  }
}
