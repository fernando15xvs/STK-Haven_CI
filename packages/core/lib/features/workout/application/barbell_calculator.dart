class Plate {
  final double weight;
  const Plate(this.weight);
}

class BarbellCalculatorResult {
  final double targetWeight;
  final double barWeight;
  final double weightPerSide;
  final List<Plate> platesPerSide;
  final double actualTotalWeight;
  final double remainder; // If the exact weight cannot be reached

  const BarbellCalculatorResult({
    required this.targetWeight,
    required this.barWeight,
    required this.weightPerSide,
    required this.platesPerSide,
    required this.actualTotalWeight,
    required this.remainder,
  });
}

class BarbellCalculator {
  /// Calculates the plates needed for ONE SIDE of the barbell using a greedy approach.
  /// 
  /// [targetWeight] is the total weight desired (including the bar).
  /// [barWeight] is the weight of the empty bar (default 20kg or 45lbs).
  /// [availablePlates] is a list of available plate weights, descending order recommended.
  static BarbellCalculatorResult calculate({
    required double targetWeight,
    double barWeight = 20.0,
    List<double> availablePlates = const [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25],
  }) {
    if (targetWeight <= barWeight) {
      return BarbellCalculatorResult(
        targetWeight: targetWeight,
        barWeight: barWeight,
        weightPerSide: 0,
        platesPerSide: [],
        actualTotalWeight: barWeight,
        remainder: targetWeight < barWeight ? 0 : targetWeight - barWeight,
      );
    }

    final plates = <Plate>[];
    double weightNeededTotal = targetWeight - barWeight;
    double weightNeededPerSide = weightNeededTotal / 2.0;
    double currentWeightPerSide = 0.0;

    // Ensure available plates are sorted descending
    final sortedPlates = List<double>.from(availablePlates)
      ..sort((a, b) => b.compareTo(a));

    double remainingWeightPerSide = weightNeededPerSide;

    for (final plateWeight in sortedPlates) {
      while (remainingWeightPerSide >= plateWeight) {
        plates.add(Plate(plateWeight));
        remainingWeightPerSide -= plateWeight;
        currentWeightPerSide += plateWeight;
        
        // Handle floating point imprecision
        remainingWeightPerSide = double.parse(remainingWeightPerSide.toStringAsFixed(3));
      }
    }

    final actualTotalWeight = barWeight + (currentWeightPerSide * 2);
    final remainder = targetWeight - actualTotalWeight;

    return BarbellCalculatorResult(
      targetWeight: targetWeight,
      barWeight: barWeight,
      weightPerSide: currentWeightPerSide,
      platesPerSide: plates,
      actualTotalWeight: actualTotalWeight,
      remainder: double.parse(remainder.toStringAsFixed(3)),
    );
  }
}
