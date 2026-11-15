import 'package:core/domain/models/body_measurement.dart';

/// Provenance for a value already entered in Medidas.
class LatestBodyValue {
  const LatestBodyValue({
    required this.value,
    required this.recordId,
    required this.recordedAt,
  });
  final double value;
  final String recordId;
  final DateTime recordedAt;
}

/// Never use the most recent record for BOTH fields: a record can contain
/// only a waist circumference, or a height taken months before the weight.
class LatestBodyMeasurements {
  const LatestBodyMeasurements({this.weightKg, this.heightCm,
    this.bodyFatPercentage});
  final LatestBodyValue? weightKg;
  final LatestBodyValue? heightCm;
  /// Independent from weight/height and never used to invent energy needs.
  final LatestBodyValue? bodyFatPercentage;

  bool get canEstimateEnergy => weightKg != null && heightCm != null;

  /// Detects edits to an existing record ID without recalculating stored plans.
  String get fingerprint =>
      '${weightKg?.recordId}:${weightKg?.value}:'
      '${weightKg?.recordedAt.microsecondsSinceEpoch}/'
      '${heightCm?.recordId}:${heightCm?.value}:'
      '${heightCm?.recordedAt.microsecondsSinceEpoch}';

  factory LatestBodyMeasurements.fromRecords(
    Iterable<BodyMeasurement> records,
  ) {
    final ordered = records.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    LatestBodyValue? weight;
    LatestBodyValue? height;
    LatestBodyValue? bodyFat;
    for (final entry in ordered) {
      if (weight == null && entry.weightKg != null &&
          entry.weightKg!.isFinite &&
          entry.weightKg! >= 35 && entry.weightKg! <= 300) {
        weight = LatestBodyValue(
          value: entry.weightKg!,
          recordId: entry.id,
          recordedAt: entry.date,
        );
      }
      if (height == null && entry.heightCm != null &&
          entry.heightCm!.isFinite &&
          entry.heightCm! >= 120 && entry.heightCm! <= 230) {
        height = LatestBodyValue(
          value: entry.heightCm!,
          recordId: entry.id,
          recordedAt: entry.date,
        );
      }
      if (bodyFat == null && entry.bodyFatPercentage != null &&
          entry.bodyFatPercentage!.isFinite &&
          entry.bodyFatPercentage! > 0 &&
          entry.bodyFatPercentage! <= 100) {
        bodyFat = LatestBodyValue(
          value: entry.bodyFatPercentage!,
          recordId: entry.id,
          recordedAt: entry.date,
        );
      }
      if (weight != null && height != null && bodyFat != null) break;
    }
    return LatestBodyMeasurements(
      weightKg: weight, heightCm: height, bodyFatPercentage: bodyFat);
  }
}
