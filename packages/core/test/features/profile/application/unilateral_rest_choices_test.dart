import 'package:core/features/profile/application/unilateral_rest_choices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommended rest choices stay unique', () {
    expect(UnilateralRestChoices.forSelected(60), [0, 30, 45, 60, 90, 120, 180]);
  });

  test('custom restored durations remain selectable', () {
    for (final custom in [1, 35, 75, 200, 599, 600]) {
      final choices = UnilateralRestChoices.forSelected(custom);
      expect(choices.where((value) => value == custom), hasLength(1));
      expect(choices, orderedEquals([...choices]..sort()));
    }
  });
}
