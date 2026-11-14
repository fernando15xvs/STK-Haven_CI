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

class _LongNamedExercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    Exercise(
      id: 'curl',
      name: 'Curl unilateral de bíceps con mancuerna en banco inclinado — variante personalizada',
      muscleGroup: 'Bíceps',
    ),
  ];
}


class _ThreeDates extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final dates = [
      DateTime(2026, 11, 4, 8, 0),
      DateTime(2026, 11, 6, 9, 30),
      DateTime(2026, 11, 9, 10, 15),
    ];
    return [
      for (var i = 0; i < dates.length; i++)
        WorkoutSession(
          id: ['session-first', 'session-middle', 'session-last'][i],
          routineNameSnapshot: i == 1 ? 'Brazos B' : 'Brazos A',
          startedAt: dates[i],
          finishedAt: dates[i].add(const Duration(minutes: 35)),
          durationSeconds: 2100,
          exercises: [
            WorkoutExercise(
              exerciseId: 'curl',
              exerciseNameSnapshot: 'Curl de bíceps',
              muscleGroupSnapshot: 'Bíceps',
              sets: [
                WorkoutSet(
                  weight: [35.0, 60.0, 70.0][i],
                  reps: [4, 3, 8][i],
                  rir: i == 1 ? null : [1, 0, 2][i],
                  completed: true,
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
      expect(find.text('Sin comparación'), findsOneWidget);
      expect(find.textContaining('· Brazos'), findsOneWidget);
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
    expect(find.textContaining('Vs. anterior:'), findsOneWidget);
    expect(find.text('Sin comparación'), findsNothing);
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
    // The old peak is outside this month's filter; it is not a valid
    // previous-session comparison inside the selected period.
    expect(find.text('Sin comparación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('long custom exercise at ${width.toInt()}px keeps complete summary',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_LongNamedExercises.new),
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: const ProgressExercisesPanel(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('variante personalizada'), findsOneWidget);
      expect(find.textContaining('· Brazos'), findsOneWidget);
      expect(find.textContaining('Último e1RM:'), findsOneWidget);
      expect(find.text('Sin comparación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.byType(ExpansionTile), findsNothing,
      reason: 'The only focused performance card must never collapse');
    expect(find.text('SESIONES RECIENTES'), findsNothing);
    expect(find.text('Técnica y ficha del ejercicio'), findsNothing);
    final action = find.byKey(const ValueKey('progress_open_history_curl'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(openedHistory?.id, 'curl');
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact search opens on demand and keeps its query when closed',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_History.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ProgressExercisesPanel(useSharedPeriod: true)),
      ),
    ));
    await tester.pumpAndSettle();
    final control = find.byKey(const ValueKey('progress_exercises_search_toggle'));
    expect(find.byKey(const ValueKey('progress_exercises_search')), findsNothing);
    await tester.tap(control);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('progress_exercises_search')), 'Curl');
    await tester.pumpAndSettle();
    expect(find.text('Extensiones'), findsNothing);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('progress_exercises_search')), findsNothing);
    expect(find.text('Extensiones'), findsNothing);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.text('Curl'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact main Progress list opens one detailed performance route',
      (tester) async {
    Exercise? opened;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_ThreeDates.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProgressExercisesPanel(
            useSharedPeriod: true,
            onOpenPerformance: (exercise) => opened = exercise,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Curl de bíceps'), findsOneWidget);
    expect(find.text('PR carga'), findsNothing);
    expect(find.text('TENDENCIAS'), findsNothing);
    expect(find.byKey(const ValueKey('progress_exercise_trend_plot')),
        findsNothing);
    expect(find.byKey(const ValueKey('progress_exercises_sort')),
        findsNothing);
    await tester.tap(
        find.byKey(const ValueKey('progress_exercises_toggle_filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('progress_exercises_sort')),
        findsOneWidget);
    await tester.tap(find.text('Ver ejercicios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curl de bíceps'));
    expect(opened?.id, 'curl');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('session chart exposes real four-metric values by date '
          '${width.toInt()}px / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            exerciseListProvider.overrideWith(_Exercises.new),
            workoutHistoryProvider.overrideWith(_ThreeDates.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const ProgressExercisesPanel(
                  initialExerciseId: 'curl',
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final dateSelector = find.byKey(
            const ValueKey('progress_exercise_session_selector'));
        await tester.ensureVisible(dateSelector);
        expect(dateSelector, findsOneWidget);
        expect(tester.widget<DropdownButton<String>>(dateSelector).value,
            'session-last');

        Finder tile(String name) => find.byKey(ValueKey(name));
        expect(find.descendant(
            of: tile('progress_session_weight'),
            matching: find.text('70 kg')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_reps'),
            matching: find.text('8')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_rir'),
            matching: find.text('2,0')), findsOneWidget);

        tester.widget<DropdownButton<String>>(dateSelector)
            .onChanged!('session-middle');
        await tester.pumpAndSettle();
        expect(find.descendant(
            of: tile('progress_session_weight'),
            matching: find.text('60 kg')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_reps'),
            matching: find.text('3')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_rir'),
            matching: find.text('Sin registrar')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_e1rm'),
            matching: find.textContaining('kg')), findsOneWidget);

        final plot = find.byKey(
            const ValueKey('progress_exercise_trend_plot'));
        await tester.ensureVisible(plot);
        await tester.pumpAndSettle();
        final rect = tester.getRect(plot);
        await tester.tapAt(Offset(rect.left + 16, rect.center.dy));
        await tester.pumpAndSettle();
        expect(tester.widget<DropdownButton<String>>(dateSelector).value,
            'session-first');
        expect(find.descendant(
            of: tile('progress_session_weight'),
            matching: find.text('35 kg')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_reps'),
            matching: find.text('4')), findsOneWidget);
        expect(find.descendant(
            of: tile('progress_session_rir'),
            matching: find.text('1,0')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

}
