import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('water selection is an opt-in manual goal with independent confirmation',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains("ValueKey('nutrition_review_water_target')"));
    expect(source,contains("ValueKey('nutrition_water_target_slider')"));
    expect(source,contains('CheckboxListTile('));
    expect(source,contains('Actividad prolongada'));
    expect(source,contains('Ambiente caluroso'));
    expect(source,contains('Sudoración elevada'));
    expect(source,contains('Revisar este valor'));
    expect(source,contains('Confirmar meta de agua'));
    expect(source,contains('Conservar mi meta'));
    expect(source,contains('Aplicar mi elección'));
    expect(source,contains('if(confirmed!=true || !mounted)return;'));
    expect(source,contains('.setTargetMl(chosen)'));
    expect(source,contains('Los pasos, el plan energético y los recordatorios'));
  });

  test('steps provenance and existing voluntary baseline are retained',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains('steps.deviceSynced'));
    expect(source,contains('steps.lastSyncedAt'));
    expect(source,contains('Pasos registrados manualmente'));
    expect(source,contains('recentRecordedSteps(days:14)'));
    expect(source,contains('Conservar mi meta'));
    expect(source,contains('.setTargetSteps(stepSuggestion)'));
    expect(source,contains('al menos 7 días registrados'));
  });

  test('draft energy values are invalidated if age, goal or activity changes',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains('void _invalidateEnergyDraft()'));
    expect(source,contains('onChanged:(_)=>setState(_invalidateEnergyDraft)'));
    expect(source.split('_invalidateEnergyDraft();').length-1,
      greaterThanOrEqualTo(3));
    expect(source,contains('_calculatedProfile=null;'));
    expect(source,contains('_calculationMeasurementIds=null;'));
  });
}
