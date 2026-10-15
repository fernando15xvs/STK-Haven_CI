import 'package:core/domain/models/body_measurement.dart';

enum MeasurementMetric {
  weight('Peso', 'kg'),
  bodyFat('Grasa corporal', '%'),
  shoulders('Hombros', 'cm'),
  chest('Pecho', 'cm'),
  waist('Cintura', 'cm'),
  hips('Caderas / glúteos', 'cm'),
  leftArm('Brazo izquierdo', 'cm'),
  rightArm('Brazo derecho', 'cm'),
  leftLeg('Pierna izquierda', 'cm'),
  rightLeg('Pierna derecha', 'cm'),
  calves('Gemelos', 'cm');

  final String label;
  final String unit;
  const MeasurementMetric(this.label, this.unit);
  double? value(BodyMeasurement m) => switch (this) {
    weight => m.weightKg,
    bodyFat => m.bodyFatPercentage,
    shoulders => m.shouldersCm,
    chest => m.chestCm,
    waist => m.waistCm,
    hips => m.hipsCm,
    leftArm => m.leftArmCm,
    rightArm => m.rightArmCm,
    leftLeg => m.leftLegCm,
    rightLeg => m.rightLegCm,
    calves => m.calvesCm,
  };
}

class MeasurementPoint {
  final DateTime date;
  final double value;
  const MeasurementPoint(this.date, this.value);
}

class MeasurementProgress {
  final List<MeasurementPoint> points;
  MeasurementProgress(
    Iterable<BodyMeasurement> measurements,
    MeasurementMetric metric,
  ) : points = [
        for (final m in measurements)
          if (metric.value(m) case final double v when v.isFinite && v > 0)
            MeasurementPoint(m.date, v),
      ]..sort((a, b) => a.date.compareTo(b.date));
  bool get canCompare =>
      points.length >= 2 && points.last.date.isAfter(points.first.date);
  double? get change =>
      canCompare ? points.last.value - points.first.value : null;
  double? get changePercent =>
      canCompare ? change! / points.first.value * 100 : null;
}

/// Calendar months (not 30-day blocks); clamp to the destination month's end.
DateTime nextMeasurementDate(
  DateTime latest,
  int months, {
  int hour = 9,
  int minute = 0,
}) {
  if (months < 1 || months > 3) throw ArgumentError.value(months, 'months');
  final lastDay = DateTime(latest.year, latest.month + months + 1, 0).day;
  return DateTime(
    latest.year,
    latest.month + months,
    latest.day > lastDay ? lastDay : latest.day,
    hour,
    minute,
  );
}
