import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/unilateral_pause_duration_field.dart';

void main() {
  test('durations format seconds and minutes without losing precision', () {
    expect(UnilateralPauseDurationField.formatSeconds(15), '15 s');
    expect(UnilateralPauseDurationField.formatSeconds(60), '1 min');
    expect(UnilateralPauseDurationField.formatSeconds(75), '1 min 15 s');
    expect(UnilateralPauseDurationField.formatSeconds(600), '10 min');
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('pause options remain visible at $width dp', (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UnilateralPauseDurationField(
            keyPrefix: 'pause',
            seconds: 60,
            onChanged: (_) {},
          ),
        ),
      ));
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.byKey(const ValueKey('pause_custom')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('custom durations validate then apply 75 seconds', (tester) async {
    var updated = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnilateralPauseDurationField(
          keyPrefix: 'pause',
          seconds: 60,
          onChanged: (seconds) => updated = seconds,
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('pause_custom')));
    await tester.pumpAndSettle();
    final entry = find.byType(TextFormField);
    expect(entry, findsOneWidget);

    await tester.enterText(entry, '0');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Introduce entre 1 y 600 segundos'), findsOneWidget);
    expect(updated, -1);

    await tester.enterText(entry, '75');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(updated, 75);
    expect(find.text('Pausa entre lados'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
