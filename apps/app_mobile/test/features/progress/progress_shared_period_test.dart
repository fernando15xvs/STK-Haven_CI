import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_shared_period_selector.dart';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
        Exercise(
          id: 'recent',
          name: 'Prensa reciente',
          muscleGroup: 'Piernas',
        ),
        Exercise(
          id: 'older',
          name: 'Remo antiguo',
          muscleGroup: 'Espalda',
        ),
      ];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final now = DateTime.now();
    return [
      for (final item in [(id: 'recent', age: 3), (id: 'older', age: 45)])
        WorkoutSession(
          id: 'session-${item.id}',
          routineNameSnapshot: 'Rutina',
          startedAt: now.subtract(Duration(days: item.age)),
          finishedAt: now.subtract(Duration(days: item.age)).add(
                const Duration(minutes: 35),
              ),
          durationSeconds: 2100,
          exercises: [
            WorkoutExercise(
              exerciseId: item.id,
              exerciseNameSnapshot: item.id,
              muscleGroupSnapshot: 'Registrado',
              sets: const [
                WorkoutSet(
                  weight: 20,
                  reps: 8,
                  completed: true,
                  setType: WorkoutSetType.working,
                ),
              ],
            ),
          ],
        ),
    ];
  }
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('shared 7D/1M/3M/1A filters exact exercise sessions at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 790);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = AppColors.from(
        const AppearanceSettings(),
        brightness,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseListProvider.overrideWith(_Exercises.new),
            workoutHistoryProvider.overrideWith(_History.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness, extensions: [colors]),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Column(
                  children: const [
                    ProgressSharedPeriodSelector(),
                    Expanded(
                      child: ProgressExercisesPanel(useSharedPeriod: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.byKey(
        const ValueKey('progress_shared_period'),
      );
      expect(selector, findsOneWidget);
      expect(find.byType(DropdownButton<ProgressPeriod>), findsNothing);
      expect(find.text('Prensa reciente'), findsOneWidget);
      expect(find.text('Remo antiguo'), findsNothing);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ProgressSharedPeriodSelector)),
      );
      expect(scope.read(timeFilterProvider), TimeFilter.month);

      tester.widget<SegmentedButton<TimeFilter>>(selector)
          .onSelectionChanged({TimeFilter.year});
      await tester.pumpAndSettle();
      expect(scope.read(timeFilterProvider), TimeFilter.year);
      expect(find.text('Remo antiguo'), findsOneWidget);

      tester.widget<SegmentedButton<TimeFilter>>(selector)
          .onSelectionChanged({TimeFilter.week});
      await tester.pumpAndSettle();
      expect(find.text('Prensa reciente'), findsOneWidget);
      expect(find.text('Remo antiguo'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('focused exercise still uses its own Todo selector',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressExercisesPanel(initialExerciseId: 'older'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<ProgressPeriod>), findsOneWidget);
    expect(find.text('Remo antiguo'), findsOneWidget);
    expect(find.text('Prensa reciente'), findsNothing);
    expect(find.byKey(const ValueKey('progress_shared_period')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
