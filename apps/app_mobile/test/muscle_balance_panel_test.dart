import 'package:core/domain/models/exercise.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/muscle_heatmap_grid.dart';

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    Exercise(
      id: 'press',
      name: 'Press banca',
      muscleGroup: 'Pecho',
      secondaryMuscles: ['Tríceps'],
    ),
    Exercise(id: 'squat', name: 'Sentadilla', muscleGroup: 'Piernas'),
  ];
}

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => [];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final finished = DateTime.now().subtract(const Duration(days: 2));
    return [
      WorkoutSession(
        id: 'w1',
        routineNameSnapshot: 'Upper',
        startedAt: finished.subtract(const Duration(minutes: 35)),
        finishedAt: finished,
        durationSeconds: 2100,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press banca',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 25, reps: 10, completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 60, reps: 8, completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'retired-exercise',
            exerciseNameSnapshot: 'Ejercicio histórico',
            muscleGroupSnapshot: 'Glúteos e isquios',
            sets: [
              WorkoutSet(
                weight: 20, reps: 10, completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

void main() {
  testWidgets('muscle balance at 320px shows zeros and toggles indirect work',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Exercises.new),
          routineListProvider.overrideWith(_Routines.new),
          workoutHistoryProvider.overrideWith(_History.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MuscleHeatmapGrid()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Balance muscular'), findsOneWidget);
    // One global filter: only Resumen has 7D/1M/3M/1A controls.
    expect(find.byType(SegmentedButton<TimeFilter>), findsNothing);
    expect(find.byKey(const ValueKey('muscle_shared_period')), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.byKey(const ValueKey('muscle_summary')), findsOneWidget);
    expect(find.textContaining('Hay etiquetas antiguas por clasificar'),
        findsOneWidget);
    expect(find.textContaining('Indirecto estimado:'), findsNothing);
    // Only a vertical list remains: no duplicate horizontal filter.
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('muscle_indirect_toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('muscle_indirect_toggle')));
    await tester.pumpAndSettle();
    // The ambiguous historical row sorts before Pecho; verify it before
    // moving down the lazy list so the test does not scroll past it.
    await tester.scrollUntilVisible(
      find.text('Glúteos e isquios · por clasificar'), 120,
    );
    expect(find.text('Glúteos e isquios · por clasificar'), findsOneWidget);
    await tester.ensureVisible(find.text('Glúteos e isquios · por clasificar'));
    await tester.pumpAndSettle();
    // ListView lazily creates cards below the fold at 320 logical pixels.
    await tester.scrollUntilVisible(find.text('Pecho'), 120);
    await tester.ensureVisible(find.text('Pecho'));
    await tester.pumpAndSettle();
    expect(find.text('Pecho'), findsOneWidget);
    await tester.tap(find.text('Pecho'));
    await tester.pumpAndSettle();
    expect(find.text('Ejercicios que aportaron trabajo directo'), findsWidgets);
    expect(find.text('Press banca'), findsWidgets);
    // Zero-activity catalogue groups are collapsed until explicitly opened.
    expect(find.text('Tríceps'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('muscle_inactive_toggle')), 120);
    await tester.tap(find.byKey(const ValueKey('muscle_inactive_toggle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tríceps'), 120);
    expect(find.textContaining('Indirecto estimado: 0.5'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Piernas'), 120);
    expect(find.text('Piernas'), findsOneWidget);
    // The shared provider updates this screen without introducing a selector.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MuscleHeatmapGrid)));
    container.read(timeFilterProvider.notifier).setFilter(TimeFilter.week);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('muscle_shared_period')), -200);
    expect(find.text('7D'), findsOneWidget);
    expect(find.byType(SegmentedButton<TimeFilter>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
