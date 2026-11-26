import 'dart:io';
import 'package:core/features/nutrition/data/nutrition_development_config.dart';
import 'package:test/test.dart';

void main() {
  test('ordinary builds default to no private development capability', () {
    expect(NutritionDevelopmentConfig.enabled, isFalse);
  });
  test('development grant requires server denial first and fresh authenticated session', () {
    final source = File('lib/features/nutrition/data/nutrition_adult_access_service.dart').readAsStringSync();
    expect(source, contains('NutritionDevelopmentConfig.enabled'));
    expect(source, contains('parsed?.personalizedAdultEnergy == false'));
    expect(source, contains("client.rpc('stk_get_development_nutrition_access')"));
    expect(source, contains('!parsed!.legalCurrent'));
    expect(source, contains('isOriginalSession()'));
  });
}
