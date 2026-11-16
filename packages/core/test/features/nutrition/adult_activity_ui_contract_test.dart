import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('activity evidence stays behind the existing server-gated adult panel',(){
    final ui=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(ui,contains('if (!hasAdultAccess)'));
    expect(ui,contains('_AdultGateCard('));
    expect(ui,contains('_buildEnergyPlanner(colors)'));
    expect(ui,contains('AdultActivitySuggestionPolicy.suggest('));
    expect(ui,contains('recentRecordedSteps(days:14)'));
    expect(ui,contains('sessions:recordedSessions'));
    expect(ui,contains('ref.watch(workoutHistoryProvider)'));
    expect(ui,contains("ValueKey('nutrition_activity_evidence')"));
    expect(ui,contains("ValueKey('nutrition_activity_no_evidence')"));
    expect(ui,contains("ValueKey('nutrition_activity_suggest_apply')"));
    expect(ui,contains('No suma el entrenamiento a los pasos'));
    expect(ui,contains('onPressed:_activity==suggested.level?null:'));
    expect(ui,contains('_activity=suggested.level;'));
    expect(ui,contains('_invalidateEnergyDraft();'));
    expect(ui,contains('initialValue: _activity'));
    expect(ui,contains("Selecciona tu actividad habitual antes de calcular."));
  });
}
