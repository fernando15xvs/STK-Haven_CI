import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding v3 personal data is optional and saves in Medidas once', () {
    final source = File('lib/features/onboarding/presentation/pages/onboarding_page.dart')
        .readAsStringSync();
    expect(source, contains('static const int _pageCount = 7'));
    expect(source, contains('_personalStep()'));
    expect(source, contains("key: const ValueKey('onboarding_birth_date')"));
    expect(source, contains("key: const ValueKey('onboarding_save_first_measurement')"));
    expect(source, contains('if (_saveFirstMeasurement)'));
    expect(source, contains('bodyMeasurementProvider.notifier'));
    expect(source, contains("stk_onboarding_first_measurement_v3"));
    expect(source, contains("!ref.read(bodyMeasurementProvider).any"));
    expect(source, contains('WeightConverter.toCanonicalKg'));
    expect(source, isNot(contains('stk_has_adult_nutrition_access')));
  });

  test('nutrition uses Medidas rather than 70 kg and 170 cm fabricated values', () {
    final core = File(
      '../../packages/core/lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    expect(core, contains('LatestBodyMeasurements.fromRecords'));
    expect(core, contains('bodyMeasurementProvider'));
    expect(core, contains('onOpenMeasurements'));
    expect(core, contains('body.fingerprint'));
    expect(core, isNot(contains("TextEditingController(text: '70')")));
    expect(core, isNot(contains("TextEditingController(text: '170')")));
    expect(core, isNot(contains("TextEditingController(text: '25')")));
    expect(mobile, contains('const BodyMeasurementPage()'));
    expect(core, contains('nutritionAccessStateProvider(widget.verifiedAdultNutritionAccess)'));
    expect(core, contains('access.canViewNumericNutrition'));
  });
}
