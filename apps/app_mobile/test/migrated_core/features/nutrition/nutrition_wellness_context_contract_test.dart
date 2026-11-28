import 'dart:io';
import '../../../support/nutrition_page_source.dart';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('water selection is an opt-in manual goal with independent confirmation',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains("ValueKey('nutrition_review_water_target')"));
    expect(source,contains("ValueKey('nutrition_water_target_slider')"));
    expect(source,contains('CheckboxListTile('));
    expect(source,contains('Actividad prolongada'));
    expect(source,contains('Ambiente caluroso'));
    expect(source,contains('Sudoración elevada'));
    expect(source,contains("ValueKey('nutrition_water_fluid_restriction')"));
    expect(source,contains("ValueKey('nutrition_water_context_guidance')"));
    expect(source,contains('onPressed:hasFluidRestriction?null:'));
    expect(source,contains('HydrationContextGuidance('));
    expect(source,contains('fluidRestriction:hasFluidRestriction'));
    expect(source,contains('Tengo indicación médica de limitar líquidos'));
    expect(source,contains('Revisar este valor'));
    expect(source,contains('Confirmar meta de agua'));
    expect(source,contains('Conservar mi meta'));
    expect(source,contains('Aplicar mi elección'));
    expect(source,contains('if(confirmed!=true || !mounted)return;'));
    expect(source,contains('.setTargetMl(chosen,'));
    expect(source,contains('source:WellnessGoalChangeSource.nutritionReview'));
    expect(source,contains('Los pasos, el plan energético y los recordatorios'));
  });

  test('steps provenance and existing voluntary baseline are retained',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains('steps.deviceSynced'));
    expect(source,contains('steps.lastSyncedAt'));
    expect(source,contains('Pasos registrados manualmente'));
    expect(source,contains('recentRecordedSteps(days:14)'));
    expect(source,contains('Conservar mi meta'));
    expect(source,contains('.setTargetSteps(suggestion,'));
    expect(source,contains('al menos 7 días registrados'));
  });

  test('saving a nutrition plan never overrides water or steps',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains('await repo.save(plan);'));
    expect(source,contains('Plan guardado. Las metas de agua y pasos'));
    expect(source,contains('Revisar metas'));
    expect(source,contains('Future<void> _reviewWellnessAfterPlanSave() async'));
    expect(source,contains("if(selected=='water')await _reviewWaterTarget();"));
    expect(source,contains("if(selected=='steps')await _reviewStepTarget();"));
    expect(source,contains("onPressed:stepSuggestion==null&&!widget.mobileCompactLayout?null:"));
    expect(source,contains('Conservar mis metas'));
  });

  test('every confirmed change is inspectable with source and date',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains("ValueKey('nutrition_wellness_goal_history')"));
    expect(source,contains('Future<void> _showWellnessGoalHistory() async'));
    expect(source,contains('water.goalChanges.reversed'));
    expect(source,contains('steps.goalChanges.reversed'));
    expect(source,contains('Revisión desde Nutrición'));
    expect(source,contains('Ajuste manual'));
  });

  test('draft energy values are invalidated if age, goal or activity changes',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains('void _invalidateEnergyDraft()'));
    expect(source,contains('onChanged:(_)=>setState(_invalidateEnergyDraft)'));
    expect(source.split('_invalidateEnergyDraft();').length-1,
      greaterThanOrEqualTo(3));
    expect(source,contains('_calculatedProfile=null;'));
    expect(source,contains('_calculationMeasurementIds=null;'));
  });
}
