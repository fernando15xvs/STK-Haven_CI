import 'package:core/features/nutrition/data/stk_nutrition_server_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no release, no receipt and no grant stay fail closed', () {
    final capabilities = StkNutritionServerCapabilities.parse({
      'personalizedAdultEnergy': false,
      'informationalFoodEstimate': false,
      'legalCurrent': false,
    });
    expect(capabilities, isNotNull);
    expect(capabilities!.personalizedAdultEnergy, isFalse);
    expect(capabilities.informationalFoodEstimate, isFalse);
  });

  test('independent reviewed adult and informational grants remain separate', () {
    final adult = StkNutritionServerCapabilities.parse({
      'personalizedAdultEnergy': true,
      'informationalFoodEstimate': false,
      'legalCurrent': true,
    })!;
    expect(adult.personalizedAdultEnergy, isTrue);
    expect(adult.informationalFoodEstimate, isFalse);
    final informational = StkNutritionServerCapabilities.parse({
      'personalizedAdultEnergy': false,
      'informationalFoodEstimate': true,
      'legalCurrent': true,
    })!;
    expect(informational.personalizedAdultEnergy, isFalse);
    expect(informational.informationalFoodEstimate, isTrue);
  });

  test('absent, contradictory and forged boolean values are never grants', () {
    for (final value in <Object?>[
      null,
      true,
      1,
      'true',
      <String, dynamic>{'verified': true},
      <String, dynamic>{
        'personalizedAdultEnergy': 'true',
        'informationalFoodEstimate': false,
        'legalCurrent': true,
      },
      <String, dynamic>{
        'personalizedAdultEnergy': true,
        'informationalFoodEstimate': false,
        'legalCurrent': false,
      },
      <String, dynamic>{
        'personalizedAdultEnergy': true,
        'informationalFoodEstimate': false,
      },
    ]) {
      expect(StkNutritionServerCapabilities.parse(value), isNull,
        reason: 'Untrusted or malformed server response cannot unlock numbers');
    }
  });
}
