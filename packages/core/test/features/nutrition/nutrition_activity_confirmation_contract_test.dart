import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adult activity is selected explicitly, not inferred from gym days', () {
    final page=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(page,contains('EnergyActivityLevel? _activity;'));
    expect(page,contains("hint: const Text('Selecciona tu actividad')"));
    expect(page,contains('if(activity==null){'));
    expect(page,contains('activityLevel: activity,'));
    expect(page,contains('Eso no determina por sí solo tu actividad diaria'));
    expect(page,isNot(contains(
      'EnergyActivityLevel _activity = EnergyActivityLevel.moderate')));
  });

  test('planner rejects non-finite weights and heights', () {
    final planner=File(
      'lib/features/nutrition/application/adult_energy_planner.dart',
    ).readAsStringSync();
    expect(planner,contains('!profile.weightKg.isFinite'));
    expect(planner,contains('!profile.heightCm.isFinite'));
  });
}
