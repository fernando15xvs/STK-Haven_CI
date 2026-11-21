import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/nutrition/presentation/pages/nutrition_internal_demo_page.dart';

/// Normal mobile CI skips this check. The isolated private QA build runs
/// with --dart-define=STK_INTERNAL_NUTRITION_DEMO=true, making it mandatory.
void main() {
  test('internal nutrition demo is enabled in explicit QA builds', () {
    expect(NutritionInternalDemoConfig.enabled, isTrue);
  }, skip: !NutritionInternalDemoConfig.enabled);
}
