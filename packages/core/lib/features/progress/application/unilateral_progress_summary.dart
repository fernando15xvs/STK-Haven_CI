import 'package:core/features/progress/application/exercise_progress_calculator.dart';

class UnilateralProgressSummary {
  final double? leftEstimated1RM;
  final double? rightEstimated1RM;
  final double? leftVolume;
  final double? rightVolume;
  final double? bestLeftEstimated1RM;
  final double? bestRightEstimated1RM;
  final double? bestLeftVolume;
  final double? bestRightVolume;
  final double? estimated1RmDifferencePercent;
  final double? volumeDifferencePercent;

  const UnilateralProgressSummary({
    this.leftEstimated1RM,
    this.rightEstimated1RM,
    this.leftVolume,
    this.rightVolume,
    this.bestLeftEstimated1RM,
    this.bestRightEstimated1RM,
    this.bestLeftVolume,
    this.bestRightVolume,
    this.estimated1RmDifferencePercent,
    this.volumeDifferencePercent,
  });

  bool get hasComparison =>
      leftEstimated1RM != null ||
      rightEstimated1RM != null ||
      leftVolume != null ||
      rightVolume != null;

  bool get hasHistoricalRecords =>
      bestLeftEstimated1RM != null ||
      bestRightEstimated1RM != null ||
      bestLeftVolume != null ||
      bestRightVolume != null;
}

/// Informational only: it describes recorded left/right values and never labels
/// either side as defective, unhealthy or a diagnosis.
class UnilateralProgressCalculator {
  const UnilateralProgressCalculator._();

  static UnilateralProgressSummary fromTrend(ExerciseProgressTrend trend) {
    ExerciseSessionPerformance? latestWithSides;
    double? bestLeftEstimated1RM;
    double? bestRightEstimated1RM;
    double? bestLeftVolume;
    double? bestRightVolume;

    for (final session in trend.sessions) {
      if (session.hasUnilateralDetail) latestWithSides = session;
      bestLeftEstimated1RM = _maxNullable(
        bestLeftEstimated1RM,
        session.leftEstimated1RM,
      );
      bestRightEstimated1RM = _maxNullable(
        bestRightEstimated1RM,
        session.rightEstimated1RM,
      );
      bestLeftVolume = _maxNullable(bestLeftVolume, session.leftVolume);
      bestRightVolume = _maxNullable(bestRightVolume, session.rightVolume);
    }

    if (latestWithSides == null) return const UnilateralProgressSummary();

    return UnilateralProgressSummary(
      leftEstimated1RM: latestWithSides.leftEstimated1RM,
      rightEstimated1RM: latestWithSides.rightEstimated1RM,
      leftVolume: latestWithSides.leftVolume,
      rightVolume: latestWithSides.rightVolume,
      bestLeftEstimated1RM: bestLeftEstimated1RM,
      bestRightEstimated1RM: bestRightEstimated1RM,
      bestLeftVolume: bestLeftVolume,
      bestRightVolume: bestRightVolume,
      estimated1RmDifferencePercent: _symmetricDifference(
        latestWithSides.leftEstimated1RM,
        latestWithSides.rightEstimated1RM,
      ),
      volumeDifferencePercent: _symmetricDifference(
        latestWithSides.leftVolume,
        latestWithSides.rightVolume,
      ),
    );
  }

  static double? _maxNullable(double? current, double? candidate) {
    if (candidate == null) return current;
    if (current == null || candidate > current) return candidate;
    return current;
  }

  static double? _symmetricDifference(double? left, double? right) {
    if (left == null || right == null || left <= 0 || right <= 0) return null;
    final average = (left + right) / 2;
    if (average == 0) return null;
    return ((left - right).abs() / average) * 100;
  }
}
