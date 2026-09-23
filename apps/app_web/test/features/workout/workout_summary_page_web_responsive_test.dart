import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_analysis.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_web/features/workout/presentation/workout_summary_page_web.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(
        showDailyVerse: false,
        vibrationEnabled: false,
        performanceMode: PerformanceMode.savings,
      );
}

void main() {
  final analysis = _analysis();

  for (final size in <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(2560, 1080),
  ]) {
    testWidgets(
      'workout summary renders without overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_TestSettingsNotifier.new),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: WorkoutSummaryPageWeb(analysisResult: analysis),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Resumen del entrenamiento'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The summary uses a lazy ListView. On the 390x844 viewport the
        // exercise-comparison section is intentionally below the fold and is
        // not built until scrolled into view. Exercise the actual responsive
        // behavior before asserting the Roadmap 2 comparison content.
        await tester.scrollUntilVisible(
          find.text('CAMBIO POR EJERCICIO'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('CAMBIO POR EJERCICIO'), findsOneWidget);
        expect(find.text('Press inclinado'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

WorkoutAnalysisResult _analysis() {
  final date = DateTime(2026, 9, 7, 18);
  final session = WorkoutSession(
    id: 'current',
    routineId: 'push-b',
    routineNameSnapshot: 'Push B',
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: const [
      WorkoutExercise(
        exerciseId: 'incline-press',
        exerciseNameSnapshot: 'Press inclinado',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          WorkoutSet(weight: 55, reps: 8, rir: 2, completed: true),
        ],
      ),
    ],
  );

  return WorkoutAnalysisResult(
    session: session,
    totalVolume: 440,
    completedSetsCount: 1,
    durationSeconds: 3600,
    personalRecords: const [],
    progressionSuggestions: const [],
    deloadSuggestions: const [],
    comparison: null,
    exerciseComparisons: [
      ExercisePerformanceComparison(
        exerciseId: 'incline-press',
        exerciseName: 'Press inclinado',
        previousPerformedAt: DateTime(2026, 9, 5, 18),
        previousRoutineName: 'Push A',
        currentVolume: 440,
        previousVolume: 400,
        currentWorkingSets: 1,
        previousWorkingSets: 1,
        currentBestWeight: 55,
        previousBestWeight: 50,
      ),
    ],
  );
}
