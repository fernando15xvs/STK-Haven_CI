import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_favorites_provider.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/progress/presentation/pages/progress_intelligence_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_history_page.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:gym_tracker/features/progress/presentation/pages/focused_exercise_progress_page.dart';
import 'package:intl/date_symbol_data_local.dart';

const _longName =
    'Curl unilateral con mancuerna en banco inclinado — variante personalizada';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
        Exercise(
          id: 'custom-alpha',
          name: _longName,
          muscleGroup: 'Bíceps',
          equipment: 'Mancuernas ajustables y banco inclinado de entrenamiento',
          secondaryMuscles: const ['Antebrazo', 'Flexores de la muñeca'],
        ),
        Exercise(
          id: 'custom-beta',
          name: 'Remo alternativo',
          muscleGroup: 'Espalda',
        ),
      ];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final date = DateTime.now().subtract(const Duration(days: 3));
    return [
      for (final id in ['custom-alpha', 'custom-beta'])
        WorkoutSession(
          id: 'session-$id',
          routineNameSnapshot: id == 'custom-alpha' ? 'Brazos' : 'Espalda',
          startedAt: date,
          finishedAt: date.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          exercises: [
            WorkoutExercise(
              exerciseId: id,
              exerciseNameSnapshot: _longName,
              muscleGroupSnapshot: id == 'custom-alpha' ? 'Bíceps' : 'Espalda',
              sets: const [
                WorkoutSet(
                  weight: 20,
                  reps: 8,
                  completed: true,
                  setType: WorkoutSetType.working,
                ),
                WorkoutSet(
                  weight: 25,
                  reps: 8,
                  completed: false,
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

class _Favorites extends ExerciseFavoriteIdsNotifier {
  @override
  Set<String> build() => {};
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  testWidgets('Progreso > Ejercicios opens exact ficha and independent history',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_History.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ProgressExercisesPanel(
              onOpenExercise: (item) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseDetailPage(exercise: item),
                ),
              ),
              onOpenHistory: (item) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseHistoryPage(exercise: item),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('progress_exercise_custom-alpha')),
        findsOneWidget);
    await tester.tap(find.text(_longName));
    await tester.pumpAndSettle();
    final ficha = find.text('Técnica y ficha del ejercicio');
    await tester.dragUntilVisible(
      ficha,
      find.byType(ListView).last,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(ficha);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailPage), findsOneWidget);
    expect(find.text('MIS REGISTROS'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProgressExercisesPanel), findsOneWidget);
    final history = find.byKey(
      const ValueKey('progress_open_history_custom-alpha'),
    );
    await tester.dragUntilVisible(
      history,
      find.byType(ListView).last,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('1 sesión registrada'), findsOneWidget);
    expect(find.byKey(
      const ValueKey('exercise_history_session-custom-beta'),
    ), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProgressExercisesPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Biblioteca > técnica > rendimiento > historial > regreso '
          '${width.toInt()}px ${brightness.name} text 1.6', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final palette = AppColors.from(
          AppearanceSettings(
            oledBlack: brightness == Brightness.dark,
            accent: AppAccent.emerald,
          ),
          brightness,
        );
        await tester.pumpWidget(ProviderScope(
          overrides: [
            exerciseListProvider.overrideWith(_Exercises.new),
            exerciseFavoriteIdsProvider.overrideWith(_Favorites.new),
            workoutHistoryProvider.overrideWith(_History.new),
            settingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              fontFamily: 'Outfit',
              extensions: [palette],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
              ),
              child: child!,
            ),
            home: const ExerciseLibraryPage(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Biblioteca'), findsOneWidget);
        final customName = find.text(_longName);
        expect(customName, findsOneWidget);
        await tester.ensureVisible(customName);
        await tester.tap(customName);
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseDetailPage), findsOneWidget);
        expect(find.text('MIS REGISTROS'), findsOneWidget);
        expect(find.byKey(const ValueKey('exercise_open_progress')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('exercise_open_history')),
            findsOneWidget);
        // Technical information owns no copy of e1RM or recent session cards.
        expect(find.text('PR carga'), findsNothing);
        expect(find.text('SESIONES RECIENTES'), findsNothing);

        final openProgress = find.byKey(
          const ValueKey('exercise_open_progress'),
        );
        await tester.ensureVisible(openProgress);
        await tester.tap(openProgress);
        await tester.pumpAndSettle();

        expect(find.byType(FocusedExerciseProgressPage), findsOneWidget);
        expect(find.byKey(const ValueKey('progress_exercise_custom-alpha')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('progress_exercise_custom-beta')),
            findsNothing);
        // A performance route started from Técnica must not link back into
        // itself and cause circular navigation.
        expect(find.text('Técnica y ficha del ejercicio'), findsNothing);

        final historyLink =
            find.byKey(const ValueKey('progress_open_history_custom-alpha'));
        await tester.dragUntilVisible(
          historyLink,
          find.byType(ListView).last,
          const Offset(0, -160),
        );
        await tester.pumpAndSettle();
        await tester.tap(historyLink);
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseHistoryPage), findsOneWidget);
        expect(find.text('1 sesión registrada'), findsOneWidget);
        expect(find.byKey(
          const ValueKey('exercise_history_session-custom-alpha'),
        ), findsOneWidget);
        expect(find.byKey(
          const ValueKey('exercise_history_session-custom-beta'),
        ), findsNothing);
        expect(find.text('Pendiente'), findsOneWidget);
        expect(find.text('Espalda'), findsNothing);

        await tester.pageBack(); // Historial -> Rendimiento.
        await tester.pumpAndSettle();
        expect(find.byType(FocusedExerciseProgressPage), findsOneWidget);
        await tester.pageBack(); // Rendimiento -> Técnica.
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseDetailPage), findsOneWidget);
        await tester.pageBack(); // Técnica -> Biblioteca.
        await tester.pumpAndSettle();
        expect(find.text('Biblioteca'), findsOneWidget);
        expect(find.text(_longName), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
