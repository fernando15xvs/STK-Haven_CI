import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/nutrition/presentation/pages/nutrition_internal_demo_page.dart';

void main() {
  testWidgets('internal demo computes adult synthetic goals only in its own route',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NutritionInternalDemoPage()),
    );
    expect(find.text('SIMULACIÓN · DATOS FICTICIOS'), findsOneWidget);
    expect(find.textContaining('No consulta servidores'), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition_demo_target')), findsOneWidget);
    final initial = tester.widget<Text>(
      find.byKey(const ValueKey('nutrition_demo_target')),
    ).data;

    final gain = find.byKey(const ValueKey('nutrition_demo_goal_gradualGain'));
    await tester.ensureVisible(gain);
    await tester.tap(gain);
    await tester.pumpAndSettle();
    final afterGain = tester.widget<Text>(
      find.byKey(const ValueKey('nutrition_demo_target')),
    ).data;
    expect(afterGain, isNot(initial));

    final teen = find.byKey(const ValueKey('nutrition_demo_teen'));
    await tester.ensureVisible(teen);
    await tester.tap(teen);
    await tester.pumpAndSettle();
    expect(find.text('Nutrición para adolescentes'), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition_demo_target')), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
  });

  testWidgets('320dp and large text: demo remains reachable without overflow',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
        ),
        child: const NutritionInternalDemoPage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final minor = find.byKey(const ValueKey('nutrition_demo_teen'));
    // At 320dp/200%, the lazy ListView may not build this chip yet.
    // Scroll until it exists instead of calling ensureVisible too early.
    await tester.scrollUntilVisible(
      minor,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(minor);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('nutrition_demo_target')), findsNothing);
  });

  test('QA flag is opt-in and never changes the RPC gate', () {
    final preview = File(
      'lib/features/nutrition/presentation/pages/nutrition_internal_demo_page.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    final core = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();

    expect(preview, contains("'STK_INTERNAL_NUTRITION_DEMO'"));
    expect(preview, contains('defaultValue: false'));
    expect(preview, isNot(contains('Supabase.instance')));
    expect(preview, isNot(contains('Hive.box')));
    expect(preview, isNot(contains('ImagePicker')));
    expect(mobile, contains('onOpenInternalDemo: NutritionInternalDemoConfig.enabled'));
    expect(mobile, contains('verifiedAdultNutritionAccess: status.allowsNumeric'));
    expect(core, contains('if (widget.onOpenInternalDemo != null)'));
    expect(core, contains('if (hasAdultAccess)'));
  });
}
