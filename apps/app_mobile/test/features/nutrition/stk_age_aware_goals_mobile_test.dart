import 'dart:io';

import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:gym_tracker/features/nutrition/presentation/widgets/stk_age_aware_nutrition_goals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget fixture({
    required StkNutritionAudience audience,
    required StkNutritionIntent selected,
    required ValueChanged<StkNutritionIntent> onSelected,
    VoidCallback? onOpenAdultPlanner,
    double textScale = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StkAgeAwareNutritionGoals(
              audience: audience,
              selected: selected,
              onSelected: onSelected,
              onOpenAdultPlanner: onOpenAdultPlanner,
            ),
          ),
        ),
      ),
    ),
    ),
  );

  testWidgets('adolescent can select all goals without adult targets',
      (tester) async {
    var selected = StkNutritionIntent.maintenance;
    var openedAdultPlanner = 0;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return fixture(
        audience: StkNutritionAudience.teen15To17,
        selected: selected,
        onSelected: (value) => setState(() => selected = value),
        onOpenAdultPlanner: () => openedAdultPlanner++,
      );
    }));
    expect(find.byKey(const ValueKey('stk_nutrition_goals_15_plus')),
        findsOneWidget);
    expect(find.text('Mantenimiento'), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.text('Déficit'), findsOneWidget);
    expect(find.byKey(const ValueKey('stk_goal_open_adult_planner')),
        findsNothing);

    final deficit = find.byKey(const ValueKey('stk_goal_deficit'));
    await tester.ensureVisible(deficit);
    await tester.tap(deficit);
    await tester.pumpAndSettle();
    expect(selected, StkNutritionIntent.deficit);
    expect(find.text('Hábitos y bienestar'), findsOneWidget);
    expect(find.textContaining('sin dietas restrictivas'), findsOneWidget);
    expect(openedAdultPlanner, 0);

    final volume = find.byKey(const ValueKey('stk_goal_volume'));
    await tester.ensureVisible(volume);
    await tester.tap(volume);
    await tester.pumpAndSettle();
    expect(selected, StkNutritionIntent.volume);
    expect(find.text('Fuerza y recuperación'), findsOneWidget);
    expect(find.textContaining('superávit calórico automático'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified adult can choose goals but cannot open calculator',
      (tester) async {
    await tester.pumpWidget(fixture(
      audience: StkNutritionAudience.adultDeclared,
      selected: StkNutritionIntent.volume,
      onSelected: (_) {},
      onOpenAdultPlanner: () {},
    ));
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.byKey(const ValueKey('stk_goal_open_adult_planner')),
        findsNothing);
    expect(find.textContaining('autorización válida del servidor'),
        findsOneWidget);
  });

  testWidgets('verified adult may open the separate calculator',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(fixture(
      audience: StkNutritionAudience.adultVerified,
      selected: StkNutritionIntent.maintenance,
      onSelected: (_) {},
      onOpenAdultPlanner: () => opens++,
    ));
    final button = find.byKey(const ValueKey('stk_goal_open_adult_planner'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opens, 1);
  });

  testWidgets('320dp/200%: chips wrap and text never overflows',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(fixture(
      audience: StkNutritionAudience.teen15To17,
      selected: StkNutritionIntent.maintenance,
      onSelected: (_) {},
      textScale: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final goal = find.byKey(const ValueKey('stk_goal_deficit'));
    await tester.ensureVisible(goal);
    await tester.pump();
    expect(goal, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('mobile opts in but frozen web route stays unmodified', () {
    final mobile = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    final core = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(mobile, contains('showAgeAwareGoals: true'));
    expect(mobile, contains('imageQuality: 78'));
    expect(mobile, contains('maxWidth: 1280'));
    expect(core, contains('this.showAgeAwareGoals = false'));
    expect(core, contains('StkAgeAwareNutritionGoals('));
    expect(core, contains('FoodVisionService.maxImageBytes'));
    expect(core, contains('if (audience.canUseAdultPlanner)'));
    expect(core, contains('StkNutritionIntent.deficit => EnergyGoal.gradualLoss'));
    expect(core, contains('StkNutritionIntent.volume => EnergyGoal.gradualGain'));
    expect(core, isNot(contains('stk_set_adult_nutrition_verification(')));
  });
}
