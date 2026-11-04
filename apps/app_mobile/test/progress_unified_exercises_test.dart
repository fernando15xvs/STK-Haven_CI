import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/exercise_progress_sort.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    Exercise(id: 'curl', name: 'Curl de bíceps', muscleGroup: 'Bíceps'),
    Exercise(id: 'extensions', name: 'Extensiones', muscleGroup: 'Tríceps'),
  ];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final now = DateTime.now().subtract(const Duration(days: 3));
    return [
      WorkoutSession(
        id: 'workout-1',
        routineId: 'arms',
        routineNameSnapshot: 'Brazos',
        startedAt: now,
        finishedAt: now.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        exercises: [
          for (final id in ['curl', 'extensions'])
            WorkoutExercise(
              exerciseId: id,
              exerciseNameSnapshot: id,
              muscleGroupSnapshot: 'Arms',
              sets: const [
                WorkoutSet(weight: 10, reps: 12, completed: true,
                    setType: WorkoutSetType.warmup),
                WorkoutSet(weight: 20, reps: 8, completed: true,
                    setType: WorkoutSetType.working),
              ],
            ),
        ],
      ),
    ];
  }
}

class _HistoryWithOlderPeak extends _History {
  @override
  List<WorkoutSession> build() => [
    WorkoutSession(
      id: 'historical-peak',
      routineNameSnapshot: 'Brazos',
      startedAt: DateTime.now().subtract(const Duration(days: 60)),
      finishedAt: DateTime.now().subtract(const Duration(days: 60))
          .add(const Duration(minutes: 30)),
      durationSeconds: 1800,
      exercises: [
        WorkoutExercise(
          exerciseId: 'curl',
          exerciseNameSnapshot: 'Curl de bíceps',
          muscleGroupSnapshot: 'Bíceps',
          sets: const [
            WorkoutSet(weight: 60, reps: 8, completed: true),
          ],
        ),
      ],
    ),
    ...super.build(),
  ];
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  testWidgets(
    'unified mobile exercise panel filters, expands and opens technical detail',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Exercise? opened;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseListProvider.overrideWith(_Exercises.new),
            workoutHistoryProvider.overrideWith(_History.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProgressExercisesPanel(
                onOpenExercise: (exercise) => opened = exercise,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Curl de bíceps'), findsOneWidget);
      expect(find.text('Extensiones'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('progress_exercises_search')), 'CuRL',
      );
      await tester.pumpAndSettle();
      expect(find.text('Curl de bíceps'), findsOneWidget);
      expect(find.text('Extensiones'), findsNothing);
      expect(find.textContaining('Último e1RM:'), findsOneWidget);
      await tester.tap(find.text('Curl de bíceps'));
      await tester.pumpAndSettle();
      expect(find.text('PR carga'), findsOneWidget);
      // The mobile route opens the same history from its existing ficha;
      // the expanded panel must not duplicate five recent sessions.
      expect(find.text('SESIONES RECIENTES'), findsNothing);
      // New historical-peak metrics can make the expanded card taller than
      // a 320x800 viewport. Scroll the real exercise list like a user, then
      // verify that the navigation control is on-screen and actionable.
      final technicalLink = find.text('Técnica y ficha del ejercicio');
      await tester.dragUntilVisible(
        technicalLink,
        find.byType(ListView),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      final linkRect = tester.getRect(technicalLink);
      expect(linkRect.center.dy, inInclusiveRange(0, 800));
      await tester.tap(technicalLink);
      expect(opened?.id, 'curl');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanded card separates last e1RM from lifetime best',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_HistoryWithOlderPeak.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: ProgressExercisesPanel(initialExerciseId: 'curl'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Último e1RM'), findsOneWidget);
    expect(find.text('Mejor e1RM histórico'), findsOneWidget);
    expect(find.textContaining('Último e1RM:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-time peak remains visible outside shared 1M period',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_HistoryWithOlderPeak.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ProgressExercisesPanel(useSharedPeriod: true)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Curl de bíceps'), findsOneWidget);
    await tester.tap(find.text('Curl de bíceps'));
    await tester.pumpAndSettle();
    expect(find.text('Último e1RM'), findsOneWidget);
    expect(find.text('Mejor e1RM histórico'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy panel without a ficha route still exposes session history',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProgressExercisesPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curl de bíceps'));
    await tester.pumpAndSettle();
    expect(find.text('SESIONES RECIENTES'), findsOneWidget);
    expect(find.text('Técnica y ficha del ejercicio'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('exercise sorting, muscle filtering and single selectable trend',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProgressExercisesPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sortFinder = find.byKey(const ValueKey('progress_exercises_sort'));
    final muscleFinder =
        find.byKey(const ValueKey('progress_exercises_muscle'));
    expect(sortFinder, findsOneWidget);
    expect(muscleFinder, findsOneWidget);

    tester.widget<DropdownButton<ExerciseProgressOrder>>(sortFinder)
        .onChanged!(ExerciseProgressOrder.inactive);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButton<ExerciseProgressOrder>>(sortFinder).value,
      ExerciseProgressOrder.inactive,
    );
    tester.widget<DropdownButton<String?>>(muscleFinder)
        .onChanged!('Tríceps');
    await tester.pumpAndSettle();
    expect(find.text('Extensiones'), findsOneWidget);
    expect(find.text('Curl de bíceps'), findsNothing);

    tester.widget<DropdownButton<String?>>(muscleFinder)
        .onChanged!(null);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Curl de bíceps'));
    await tester.tap(find.text('Curl de bíceps'));
    await tester.pumpAndSettle();

    final trendFinder =
        find.byKey(const ValueKey('progress_exercise_trend_selector'));
    await tester.ensureVisible(trendFinder.first);
    expect(trendFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('progress_exercise_trend_plot')),
      findsOneWidget,
    );
    tester.widget<DropdownButton<ExerciseTrendMetric>>(trendFinder)
        .onChanged!(ExerciseTrendMetric.rir);
    await tester.pumpAndSettle();
    expect(find.text('Sin datos de RIR registrados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('progress_exercise_trend_plot')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused performance opens exact exercise and full history',
      (tester) async {
    Exercise? openedHistory;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProgressExercisesPanel(
              initialExerciseId: 'curl',
              onOpenHistory: (exercise) => openedHistory = exercise,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Curl de bíceps'), findsOneWidget);
    expect(find.text('Extensiones'), findsNothing);
    expect(find.byKey(const ValueKey('progress_exercises_search')), findsNothing);
    expect(find.byKey(const ValueKey('progress_exercise_curl')), findsOneWidget);
    expect(find.text('SESIONES RECIENTES'), findsNothing);
    expect(find.text('Técnica y ficha del ejercicio'), findsNothing);
    final action = find.byKey(const ValueKey('progress_open_history_curl'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(openedHistory?.id, 'curl');
    expect(tester.takeException(), isNull);
  });
}
