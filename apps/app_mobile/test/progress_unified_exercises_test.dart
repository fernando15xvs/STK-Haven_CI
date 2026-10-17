import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
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
      await tester.tap(find.text('Curl de bíceps'));
      await tester.pumpAndSettle();
      expect(find.text('PR carga'), findsOneWidget);
      await tester.ensureVisible(find.text('Técnica y ficha del ejercicio'));
      await tester.tap(find.text('Técnica y ficha del ejercicio'));
      expect(opened?.id, 'curl');
      expect(tester.takeException(), isNull);
    },
  );
}
