import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:gym_tracker/features/nutrition/presentation/widgets/stk_mobile_nutrition_goal_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget fixture({
    StkNutritionAudience audience = StkNutritionAudience.teen15To17,
    StkNutritionIntent selected = StkNutritionIntent.maintenance,
    required ValueChanged<StkNutritionIntent> onSelected,
    VoidCallback? onPlanner,
    double textScale = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StkMobileNutritionGoalSelector(
              audience: audience,
              selected: selected,
              onSelected: onSelected,
              onOpenAdultPlanner: onPlanner,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('teen goal choices stay useful without numeric or diet targets',
      (tester) async {
    var selected = StkNutritionIntent.maintenance;
    var plannerOpens = 0;
    await tester.pumpWidget(
      StatefulBuilder(builder: (context, setState) => fixture(
        audience: StkNutritionAudience.teen15To17,
        selected: selected,
        onSelected: (value) => setState(() => selected = value),
        onPlanner: () => plannerOpens++,
      )),
    );

    expect(find.byKey(const ValueKey('stk_mobile_nutrition_goal_selector')),
        findsOneWidget);
    expect(find.text('Tu objetivo'), findsOneWidget);
    expect(find.text('Mantenimiento'), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.text('Déficit'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stk_mobile_goal_deficit')));
    await tester.pumpAndSettle();
    expect(selected, StkNutritionIntent.deficit);
    expect(find.text('Hábitos y bienestar, sin dietas restrictivas.'),
        findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.byKey(const ValueKey('stk_mobile_open_adult_planner')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('stk_mobile_goal_volume')));
    await tester.pumpAndSettle();
    expect(selected, StkNutritionIntent.volume);
    expect(find.textContaining('Entrena fuerza'), findsOneWidget);
    expect(plannerOpens, 0);
  });

  testWidgets('unverified adult is guidance only', (tester) async {
    var called = 0;
    await tester.pumpWidget(fixture(
      audience: StkNutritionAudience.adultDeclared,
      selected: StkNutritionIntent.volume,
      onSelected: (_) {},
      onPlanner: () => called++,
    ));
    expect(find.text('Alimentación suficiente para progresar con fuerza.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('stk_mobile_open_adult_planner')),
        findsNothing);
    expect(called, 0);
  });

  testWidgets('verified adult may review planner, not save automatically',
      (tester) async {
    var called = 0;
    await tester.pumpWidget(fixture(
      audience: StkNutritionAudience.adultVerified,
      onSelected: (_) {},
      onPlanner: () => called++,
    ));
    await tester.tap(find.byKey(const ValueKey('stk_mobile_open_adult_planner')));
    expect(called, 1);
    expect(find.textContaining('kcal'), findsNothing);
  });

  testWidgets('unknown age and under-15 do not open numeric planner',
      (tester) async {
    for (final audience in [
      StkNutritionAudience.under15,
      StkNutritionAudience.unknownAge,
    ]) {
      await tester.pumpWidget(fixture(
        audience: audience,
        onSelected: (_) {},
        onPlanner: () => fail('No plan for this audience'),
      ));
      expect(find.byKey(const ValueKey('stk_mobile_open_adult_planner')),
          findsNothing);
      expect(find.textContaining('kcal'), findsNothing);
    }
  });

  testWidgets('320dp / 200% text: goal controls are all reachable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    var count = 0;
    await tester.pumpWidget(fixture(
      selected: StkNutritionIntent.maintenance,
      onSelected: (_) => count++,
      textScale: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final intent in StkNutritionIntent.values) {
      final item = find.byKey(ValueKey('stk_mobile_goal_${intent.name}'));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }
    expect(count, 3);
    expect(tester.takeException(), isNull);
  });
}
