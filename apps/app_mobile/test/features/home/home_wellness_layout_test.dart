import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/home/presentation/widgets/home_wellness_layout.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('wellness stays readable at $width dp and text $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: HomeWellnessLayout(
                    hydration: const Card(child: Padding(
                      padding: EdgeInsets.all(12), child: Text('Agua +250 ml'))),
                    steps: const Card(child: Padding(
                      padding: EdgeInsets.all(12), child: Text('Pasos diarios'))),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final horizontal = width >= 390 && scale == 1.0;
        expect(find.byKey(ValueKey(horizontal
            ? 'home_wellness_horizontal' : 'home_wellness_vertical')),
            findsOneWidget);
        expect(find.text('Agua +250 ml'), findsOneWidget);
        expect(find.text('Pasos diarios'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
