import 'package:gym_tracker/features/workout/presentation/widgets/active_workout_memory_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/workout_rest_controls.dart';

void main() {
  testWidgets('contextual memory targets the exact exercise instead of a floating launcher',
      (tester) async {
    String? openedInstanceId;
    await tester.pumpWidget(MaterialApp(
      home: ActiveWorkoutMemoryAccess(
        openForExercise: (id) => openedInstanceId = id,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ActiveWorkoutMemoryAccess.maybeOf(context)
                  ?.openForExercise('exercise-02-instance'),
              child: const Text('Memoria del ejercicio'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Memoria del ejercicio'));
    expect(openedInstanceId, 'exercise-02-instance');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('compact rest at ${width.toInt()}dp x$scale dark=$dark',
            (tester) async {
          tester.view.physicalSize = Size(width, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var skip = 0;
          var add15 = 0;
          var add30 = 0;
          var custom = 0;
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              fontFamily: 'Outfit',
            ),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                ),
                child: ListView(
                  children: [
                    WorkoutRestControls(
                      remainingSeconds: 12,
                      onSkip: () => skip++,
                      onAdd15: () => add15++,
                      onAdd30: () => add30++,
                      onCustomize: () => custom++,
                    ),
                  ],
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('rest_banner')), findsOneWidget);
          expect(find.byKey(const ValueKey('workout_rest_countdown')),
              findsOneWidget);
          expect(find.text('00:12'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('+15 s'));
          await tester.tap(find.text('+30 s'));
          await tester.tap(find.text('Personalizar'));
          await tester.tap(find.text('Omitir'));
          expect([add15, add30, custom, skip], [1, 1, 1, 1]);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('rest seconds clamp for UI only and callbacks retain original authority',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkoutRestControls(
          remainingSeconds: -4,
          onSkip: () {},
          onAdd15: () {},
          onAdd30: () {},
          onCustomize: () {},
        ),
      ),
    ));
    expect(find.text('00:00'), findsOneWidget);
  });
}
