import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
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
  testWidgets('horizontal wellness cards match height with different content',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: HomeWellnessLayout(
              hydration: Card(
                key: ValueKey('hydration_size_test'),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Agua'),
                ),
              ),
              steps: Card(
                key: ValueKey('steps_size_test'),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pasos'),
                      Text('Conectar sensor'),
                      Text('Permiso pendiente'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final water = tester.getSize(find.byKey(const ValueKey('hydration_size_test')));
    final steps = tester.getSize(find.byKey(const ValueKey('steps_size_test')));
    expect(water.height, steps.height);
    expect(water.width, steps.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OLED/accent theme remains safe at large text sizes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final colors = AppColors.from(
      const AppearanceSettings(oledBlack: true, accent: AppAccent.emerald),
      Brightness.dark,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Outfit',
        extensions: [colors],
      ),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: HomeWellnessLayout(
            hydration: const Card(child: Text('Hidratación 2 500 ml')),
            steps: const Card(child: Text('10 000 pasos del día')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_wellness_vertical')),
        findsOneWidget);
    expect(find.text('Hidratación 2 500 ml'), findsOneWidget);
    expect(find.text('10 000 pasos del día'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

