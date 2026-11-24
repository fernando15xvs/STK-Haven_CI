import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:gym_tracker/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    testWidgets('Ejercicios lists all history regardless of shared period at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 790);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = AppColors.from(
        const AppearanceSettings(), brightness);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseListProvider.overrideWith(_Exercises.new),
            workoutHistoryProvider.overrideWith(_History.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness, extensions: [colors]),
            home: const Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
                child: ProgressExercisesPanel(useSharedPeriod: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress_shared_period')), findsNothing);
      expect(find.byType(DropdownButton<ProgressPeriod>), findsNothing);
      expect(find.text('Prensa reciente'), findsOneWidget);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ProgressExercisesPanel)));
      scope.read(timeFilterProvider.notifier).setFilter(TimeFilter.week);
      await tester.pumpAndSettle();
      expect(scope.read(timeFilterProvider), TimeFilter.week);
      await tester.scrollUntilVisible(
        find.text('Remo antiguo'), 130,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(find.text('Remo antiguo'), findsOneWidget);
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
