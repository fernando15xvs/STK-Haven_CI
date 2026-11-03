import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_demonstration_card.dart';

void main() {
  testWidgets('bench press explains steps without mismatched visual',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bench = presetExercises.firstWhere((e) => e.id == 'ex_bench_press');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExerciseDemonstrationCard(exercise: bench),
        ),
      ),
    ));
    expect(find.text('CÓMO REALIZAR EL EJERCICIO'), findsOneWidget);
    expect(find.byKey(const Key('exercise_media_fallback')), findsOneWidget);
    expect(find.byKey(const Key('exercise_verified_media')), findsNothing);
    expect(find.text('1. Preparación'), findsOneWidget);
    expect(find.text('2. Ejecución'), findsOneWidget);
    expect(find.text('3. Evita estos errores'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user-created exercise retains personal instructions',
      (tester) async {
    final exercise = Exercise(
      id: 'custom_1', name: 'Movimiento personalizado',
      muscleGroup: 'Hombro', instructions: 'Hazlo según mi planificación.',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ExerciseDemonstrationCard(exercise: exercise)),
    ));
    expect(find.text('Instrucciones guardadas'), findsOneWidget);
    expect(find.text('Hazlo según mi planificación.'), findsOneWidget);
    expect(find.byKey(const Key('exercise_verified_media')), findsNothing);
  });

  testWidgets('reduced motion never requires an animation or asset download',
      (tester) async {
    final exercise = presetExercises.firstWhere(
        (e) => e.id == 'exv2_nordic_curl');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExerciseDemonstrationCard(
          exercise: exercise, reduceMotion: true,
        ),
      ),
    ));
    expect(find.byKey(const Key('exercise_media_fallback')), findsOneWidget);
    expect(find.byKey(const Key('exercise_toggle_animation')), findsNothing);
    expect(find.text('2. Ejecución'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('unverified exercise has exactly one empty message in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exercise = Exercise(
        id: 'custom_without_guide',
        name: 'Movimiento sin material',
        muscleGroup: 'General',
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: ExerciseDemonstrationCard(exercise: exercise),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise_media_fallback')), findsOneWidget);
      expect(find.textContaining('Este ejercicio aún no tiene demostración'),
          findsOneWidget);
      expect(find.textContaining('Todavía no hay una guía verificada'),
          findsNothing);
      expect(find.textContaining('Guía general orientativa'), findsNothing);
      expect(find.byKey(const Key('exercise_verified_media')), findsNothing);
      expect(find.byKey(const Key('exercise_toggle_animation')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

}
