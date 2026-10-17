import 'package:core/domain/models/exercise.dart';
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
    expect(find.text('Piernas'), findsOneWidget);
    expect(find.text('Pecho'), findsOneWidget);
    expect(find.textContaining('Indirecto estimado:'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('muscle_indirect_toggle')));
    await tester.tap(find.byKey(const ValueKey('muscle_indirect_toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Indirecto estimado: 0.5'), findsWidgets);
    await tester.ensureVisible(find.text('Pecho'));
    await tester.tap(find.text('Pecho'));
    await tester.pumpAndSettle();
    expect(find.text('Ejercicios que aportaron trabajo directo'), findsWidgets);
    expect(find.text('Press banca'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
