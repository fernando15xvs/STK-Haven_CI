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
  const LatestBodyMeasurements({this.weightKg, this.heightCm});
  final LatestBodyValue? weightKg;
  final LatestBodyValue? heightCm;

  bool get canEstimateEnergy => weightKg != null && heightCm != null;

  factory LatestBodyMeasurements.fromRecords(
    Iterable<BodyMeasurement> records,
  ) {
    final ordered = records.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    LatestBodyValue? weight;
    LatestBodyValue? height;
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
      if (weight != null && height != null) break;
    }
    return LatestBodyMeasurements(weightKg: weight, heightCm: height);
  }
}
