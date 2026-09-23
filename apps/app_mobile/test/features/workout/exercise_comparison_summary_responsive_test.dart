import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/exercise_comparison_summary.dart';

void main() {
  final comparison = ExercisePerformanceComparison(
    exerciseId: 'incline-press',
    exerciseName: 'Press inclinado con mancuernas',
    previousPerformedAt: DateTime(2026, 9, 5, 18),
    previousRoutineName: 'Push A con un nombre deliberadamente largo',
    currentVolume: 1320,
    previousVolume: 1200,
    currentWorkingSets: 3,
    previousWorkingSets: 3,
    currentBestWeight: 55,
    previousBestWeight: 52.5,
  );

  for (final size in <Size>[
    const Size(320, 640),
    const Size(390, 844),
    const Size(600, 960),
  ]) {
    testWidgets(
      'exercise comparison remains usable at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseComparisonSummary(
                  comparison: comparison,
                  unit: WeightUnit.kg,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Press inclinado con mancuernas'), findsOneWidget);
        expect(find.textContaining('Última ejecución global'), findsOneWidget);
        expect(find.textContaining('Volumen'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
