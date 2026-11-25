import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Inicio exposes one compact Mi plan link without extra wellness cards',(){
    final dashboard=File(
      'lib/features/home/presentation/pages/dashboard_page.dart',
    ).readAsStringSync();
    expect(dashboard.split('HomeWellnessLayout(').length-1,1);
    expect(dashboard.split("ValueKey('home_open_nutrition_plan')").length-1,1);
    expect(dashboard,contains("label:const Text('Nutrición')"));
    expect(dashboard,contains('const NutritionIntelligencePageMobile()'));
    expect(dashboard.indexOf("ValueKey('home_open_nutrition_plan')"),
      lessThan(dashboard.indexOf('HomeWellnessLayout(')));
    final layout=File(
      'lib/features/home/presentation/widgets/home_wellness_layout.dart',
    ).readAsStringSync();
    expect(layout,contains('IntrinsicHeight('));
    expect(layout,contains('crossAxisAlignment: CrossAxisAlignment.stretch'));
  });

  test('Inicio places an opt-in compact reflection before training and recovery',
      () {
    final source = File(
      'lib/features/home/presentation/pages/dashboard_page.dart',
    ).readAsStringSync();
    final greeting = source.indexOf('_GreetingHeader(now: _observedAt)');
    final message = source.indexOf('const _DailyMessageCard(),');
    final activeAccess = source.indexOf('if (activeWorkout.isActive) ...[');
    final recoveryHeading = source.indexOf("'RECUPERACIÓN'");
    final recovery = source.indexOf('RecoveryCheckInCard(');
    final wellness = source.indexOf("'BIENESTAR'");
    final habits = source.indexOf('HomeHabitsCard(now: _observedAt)');
    final sleep = source.indexOf('HomeSleepCard(now: _observedAt)');
    expect(greeting, greaterThanOrEqualTo(0));
    expect(message, greaterThan(greeting));
    expect(activeAccess, greaterThan(message));
    expect(recoveryHeading, greaterThan(activeAccess));
    expect(recovery, greaterThan(recoveryHeading));
    expect(wellness, greaterThan(recovery));
    expect(sleep, greaterThan(recovery));
    expect(sleep, lessThan(wellness));
    expect(habits, greaterThan(wellness));
    expect(source, isNot(contains("'ACTIVIDAD SEMANAL'")));
    expect(source, contains('faithEnabled && settings.showDailyVerse'));
    expect(source, contains('loadingCard(providerError: true)'));
    expect(source, contains("ValueKey('home_daily_reflection')"));
    expect(source, contains('maxLines: 4,'));
    expect(source, isNot(contains("'TU ENTRENAMIENTO'")));
    expect(source, isNot(contains("'Ir a Entrenar'")));
    expect(source, isNot(contains("const Text('Leer completo')")));
    expect(source, isNot(contains("'MENSAJE DE HOY'")));
    expect(source, isNot(contains('Icon(Icons.bolt')));
    expect(source, isNot(contains('ContextualPassageDetails(')));
  });
}
