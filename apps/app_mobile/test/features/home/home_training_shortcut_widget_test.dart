import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/home/presentation/widgets/home_training_shortcut.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'Inicio compact continuation works at ${width.toInt()}dp, $scale, $brightness',
          (tester) async {
            tester.view.physicalSize = Size(width, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            var continues = 0;
            await tester.pumpWidget(MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: HomeTrainingShortcut(
                        routineName: 'Upper B',
                        isPendingReview: false,
                        onContinue: () => continues++,
                      ),
                    ),
                  ),
                ),
              ),
            ));

            expect(find.byKey(const ValueKey('home_continue_workout')),
                findsOneWidget);
            expect(find.text('Continuar · Upper B'), findsOneWidget);
            expect(
              tester.getSize(find.byKey(const ValueKey('home_continue_workout'))).height,
              greaterThanOrEqualTo(44),
            );
            expect(tester.takeException(), isNull);

            await tester.tap(find.byKey(const ValueKey('home_continue_workout')));
            await tester.pump();
            expect(continues, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('stale session remains a continuation, never a new workout',
      (tester) async {
    var continues = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeTrainingShortcut(
          routineName: 'Lower A',
          isPendingReview: true,
          onContinue: () => continues++,
        ),
      ),
    ));
    expect(find.text('Pendiente de revisar · Lower A'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Entrenamiento pendiente.*Continuar Lower A')),
      findsOneWidget,
    );
    expect(find.textContaining('Iniciar'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home_continue_workout')));
    expect(continues, 1);
    expect(tester.takeException(), isNull);
    } finally {
      // WidgetTester verifies open semantics handles before addTearDown.
      // Dispose synchronously, including when any assertion fails.
      semantics.dispose();
    }
  });
}
