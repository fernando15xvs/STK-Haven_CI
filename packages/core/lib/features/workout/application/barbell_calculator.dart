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

  bool get exact => remainder.abs() < 0.001;
  bool get belowBar => targetWeight < barWeight;

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
  /// Finds the closest balanced load not exceeding the target. Inventory is
  /// the number of physical discs (two are needed for each balanced pair).
  /// Legacy callers can omit inventory and use the standard disc set.
  static BarbellCalculatorResult calculate({
    required double targetWeight,
    double barWeight = 20.0,
    List<double> availablePlates = const [25, 20, 15, 10, 5, 2.5, 1.25],
    Map<double, int>? inventory,
  }) {
    if (!targetWeight.isFinite || !barWeight.isFinite ||
        targetWeight <= 0 || targetWeight > 2000 || barWeight <= 0 ||
        barWeight > 2000) {
      throw ArgumentError('Peso de barra u objetivo inválido');
    }
    final capacity = (((targetWeight - barWeight) / 2) * 1000 + 1e-7).floor();
    final sorted = availablePlates.where((p) =>
        p.isFinite && p >= 0.25 && p <= 100).toSet().toList()
      ..sort((a,b) => b.compareTo(a));
    // Bounded subset sum with binary grouped pairs. Integer millesimal units
    // avoid floating point loops and support 1.25 and 2.5 kg/lb discs.
    final reachable = <int, List<Plate>>{0: const []};
    if (capacity > 0) {
      for (final plate in sorted) {
        final step = (plate * 1000).round();
        var count = capacity ~/ step;
        if (inventory != null) {
          final pairs = (inventory[plate] ?? 0).clamp(0, 200).toInt() ~/ 2;
          if (pairs < count) count = pairs;
        }
        var batch = 1;
        while (count > 0) {
          final take = batch < count ? batch : count;
          final delta = step * take;
          final snapshot = reachable.entries.toList(growable:false);
          for (final entry in snapshot) {
            final weight = entry.key + delta;
            if (weight > capacity) continue;
            final previous = reachable[weight];
            if (previous == null || previous.length > entry.value.length + take) {
              reachable[weight] = [...entry.value, for(var i=0;i<take;i++) Plate(plate)];
            }
          }
          count -= take;
          batch *= 2;
        }
      }
    }
    final best = reachable.keys.reduce((a,b)=>a>b?a:b);
    final plates = reachable[best]!;
    final side = best / 1000;
    final actual = barWeight + side * 2;
    return BarbellCalculatorResult(targetWeight:targetWeight,barWeight:barWeight,
      weightPerSide:side,platesPerSide:List.unmodifiable(plates),
      actualTotalWeight:actual,remainder:double.parse((targetWeight-actual).toStringAsFixed(3)));
  }
}
