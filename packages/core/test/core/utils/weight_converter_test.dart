import 'package:flutter_test/flutter_test.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';

void main() {
  group('WeightConverter', () {
    test('displayWeight converts kg to lb and rounds correctly', () {
      // 100 kg -> 220.462 lb -> should display as 220.5 (or whatever precision we use)
      final lb = WeightConverter.displayWeight(100.0, WeightUnit.lb);
      expect(lb, closeTo(220.46, 0.01)); // Assuming full precision returned, UI limits digits
      
      final kg = WeightConverter.displayWeight(100.0, WeightUnit.kg);
      expect(kg, 100.0);
    });

    test('toCanonicalKg converts lb to kg accurately', () {
      // 220.46 lb -> 100 kg
      final kg = WeightConverter.toCanonicalKg(220.46226218, WeightUnit.lb);
      expect(kg, closeTo(100.0, 0.01));

      final kgSame = WeightConverter.toCanonicalKg(100.0, WeightUnit.kg);
      expect(kgSame, 100.0);
    });
    
    test('end-to-end conversion retains reasonable precision', () {
      const originalKg = 85.5;
      final asLb = WeightConverter.displayWeight(originalKg, WeightUnit.lb);
      final backToKg = WeightConverter.toCanonicalKg(asLb, WeightUnit.lb);
      
      expect(backToKg, closeTo(originalKg, 0.0001));
    });
  });
}
