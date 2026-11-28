import 'dart:io';
import '../../../support/nutrition_page_source.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adult activity is selected explicitly, not inferred from gym days', () {
    final page=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(page,contains('EnergyActivityLevel? _activity;'));
    expect(page,contains("hint: const Text('Selecciona tu actividad')"));
    expect(page,contains('if(activity==null){'));
    expect(page,contains('activityLevel: activity,'));
    expect(page,contains('Eso no determina por sí solo tu actividad diaria'));
    expect(page,isNot(contains(
      'EnergyActivityLevel _activity = EnergyActivityLevel.moderate')));
  });

  test('adult nutrition compares dated Medidas without its own weight storage', () {
    final page=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(page,contains('NutritionWeightTrend.fromRecords(measurementRecords)'));
    expect(page,contains('if(trend!=null)'));
    expect(page,contains('Ver historial completo en Medidas'));
    expect(page,contains('No representa por sí sola éxito o fracaso.'));
  });

  test('saved plan discloses dated sources and server-check provenance',(){
    final page=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(page,contains("ValueKey('nutrition_plan_snapshot_details')"));
    expect(page,contains('plan.weightRecordedAt'));
    expect(page,contains('plan.heightRecordedAt'));
    expect(page,contains('plan.formulaVersion'));
    expect(page,contains('plan.accessCheckedAt'));
    expect(page,contains('Esto no concede ni mantiene un permiso actual.'));
  });

  test('planner rejects non-finite weights and heights', () {
    final planner=File(
      '../../packages/core/lib/features/nutrition/application/adult_energy_planner.dart',
    ).readAsStringSync();
    expect(planner,contains('!profile.weightKg.isFinite'));
    expect(planner,contains('!profile.heightCm.isFinite'));
  });
}
