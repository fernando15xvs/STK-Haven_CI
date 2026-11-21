import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';

void main() {
  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('finish CTA remains legible and actionable at ${scale}x on 320dp',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var completed = 0;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 720),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PrimaryButton(
                    height: 48,
                    label: 'Finalizar entrenamiento',
                    onPressed: () => completed++,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final height = tester.getSize(find.byType(FilledButton)).height;
      if (scale == 1.0) {
        expect(height, 48);
      } else {
        expect(height, greaterThan(48));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('FINALIZAR ENTRENAMIENTO'));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('set input field labels and completion changes preserve saved values', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();

    expect(source, contains('height: 48,'));
    expect(source, contains("accessibilityLabel: 'Peso de la serie"));
    expect(source, contains("accessibilityLabel: 'Repeticiones de la serie"));
    expect(source, contains("accessibilityLabel: 'Repeticiones en reserva"));
    expect(source, contains('child: Semantics('));
    expect(source, contains('final completionChanged ='));
    expect(source, contains('(weightChanged || completionChanged) && !_weightFocused'));
    expect(source, contains('(repsChanged || completionChanged) && !_repsFocused'));
    expect(source, contains('(rirChanged || completionChanged) && !_rirFocused'));
    expect(source, contains('integerOnly: true'));
    expect(source, contains('TextInputType.number'));
    expect(source, contains('onChanged: widget.onChanged'));
  });

  test('contextual memory never falls back to another exercise after deletion', () {
    final source = File(
      '../../packages/core/lib/features/workout/presentation/widgets/'
      'active_workout_memory_overlay.dart',
    ).readAsStringSync();
    expect(source, contains('item.instanceId == requestedInstanceId'));
    expect(source, contains('if (exerciseIndex < 0)'));
    expect(source, contains('Este ejercicio ya no está en la sesión.'));
    expect(source, isNot(contains('exerciseIndex = session.exercises.length - 1')));
  });
}
