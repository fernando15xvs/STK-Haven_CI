import 'package:core/domain/models/body_measurement.dart';

/// Neutral, read-only comparison of two actual dated weight records.
/// Medidas is the only source of truth; no predicted or invented points.
class NutritionWeightTrend {
  const NutritionWeightTrend({
    required this.previousWeightKg,
    required this.latestWeightKg,
    required this.previousDate,
    required this.latestDate,
    required this.previousRecordId,
    required this.latestRecordId,
  });

  final double previousWeightKg;
  final double latestWeightKg;
  final DateTime previousDate;
  final DateTime latestDate;
  final String previousRecordId;
  final String latestRecordId;

  double get differenceKg => latestWeightKg-previousWeightKg;

  /// Same-day edits are not treated as a longitudinal trend; use the most
  /// recent valid entry from each distinct calendar day.
  static NutritionWeightTrend? fromRecords(Iterable<BodyMeasurement> records) {
    final ordered=records.toList()
      ..sort((a,b)=>b.date.compareTo(a.date));
    BodyMeasurement? newest;
    BodyMeasurement? previous;
    for(final entry in ordered) {
      final weight=entry.weightKg;
      if(weight==null || !weight.isFinite || weight<35 || weight>300)continue;
      if(newest==null){
        newest=entry;
        continue;
      }
      if(entry.date.year==newest.date.year &&
         entry.date.month==newest.date.month &&
         entry.date.day==newest.date.day)continue;
      previous=entry;
      break;
    }
    if(newest==null || previous==null)return null;
    return NutritionWeightTrend(
      previousWeightKg:previous.weightKg!,
      latestWeightKg:newest.weightKg!,
      previousDate:previous.date,
      latestDate:newest.date,
      previousRecordId:previous.id,
      latestRecordId:newest.id,
    );
  }
}
