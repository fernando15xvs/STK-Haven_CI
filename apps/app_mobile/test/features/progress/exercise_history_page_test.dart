import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_history_page.dart';
import 'package:intl/date_symbol_data_local.dart';

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final today = DateTime(2026, 11, 2, 10);
    return [
      for (var i = 0; i < 6; i++)
        WorkoutSession(
          id: 'session-$i',
          routineId: 'routine',
          routineNameSnapshot: 'Rutina $i',
          startedAt: today.subtract(Duration(days: i)),
          finishedAt: today.subtract(Duration(days: i)).add(
                const Duration(minutes: 40),
              ),
          durationSeconds: 2400,
          exercises: [
            WorkoutExercise(
              exerciseId: 'bench',
              exerciseNameSnapshot: 'Press',
              muscleGroupSnapshot: 'Pecho',
              sets: [
                const WorkoutSet(
                  weight: 30,
                  reps: 8,
                  completed: true,
                ),
                if (i == 0)
                  const WorkoutSet(
                    weight: 32.5,
                    reps: 8,
                    completed: false,
                  ),
              ],
            ),
          ],
        ),
      WorkoutSession(
        id: 'another-exercise',
        routineId: 'other',
        routineNameSnapshot: 'No relacionado',
        startedAt: today,
        finishedAt: today.add(const Duration(minutes: 15)),
        durationSeconds: 900,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'squat',
            exerciseNameSnapshot: 'Sentadilla',
            muscleGroupSnapshot: 'Piernas',
            sets: [WorkoutSet(weight: 40, reps: 6, completed: true)],
          ),
        ],
      ),
    ];
  }
}

class _EmptyHistory extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() => const [];
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  final exercise = Exercise(
    id: 'bench',
    name: 'Press de banca',
    muscleGroup: 'Pecho',
  );

  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('full history shows 6 matches and pending sets in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final palette = AppColors.from(
        const AppearanceSettings(),
        brightness,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          workoutHistoryProvider.overrideWith(_History.new),
          settingsProvider.overrideWith(_Settings.new),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [palette]),
          home: ExerciseHistoryPage(exercise: exercise),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('6 sesiones registradas'), findsOneWidget);
      expect(find.text('Rutina 0'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('No relacionado'), findsNothing);
      expect(
        find.byKey(const ValueKey('exercise_history_session-0')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise_history_session-5')),
        250,
      );
      expect(
        find.byKey(const ValueKey('exercise_history_session-5')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty history remains neutral and read-only', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workoutHistoryProvider.overrideWith(_EmptyHistory.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        home: ExerciseHistoryPage(exercise: exercise),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Aún no hay sesiones registradas'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
