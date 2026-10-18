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

class _Catalog extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
        Exercise(id: 'a', name: 'Press',
            muscleGroup: 'Hombros',
            secondaryMuscles: const ['Tríceps y hombro']),
        Exercise(id: 'b', name: 'Peso muerto',
            muscleGroup: 'Isquios'),
      ];
}

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => [
        Routine(
          id: 'r', name: 'Rutina',
          createdAt: DateTime(2026, 9, 1), scheduledDays: const [],
          exercises: const [
            RoutineExercise(exerciseId: 'a', order: 0,
                targetSets: 3, targetRepsMin: 8,
                targetRepsMax: 12, restSeconds: 90),
          ],
        ),
      ];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() {
    final now = DateTime.now();
    return [
      WorkoutSession(
        id: 'history-1', routineId: 'r',
        routineNameSnapshot: 'Rutina antigua',
        startedAt: now.subtract(const Duration(days: 2, hours: 1)),
        finishedAt: now.subtract(const Duration(days: 2)),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'historical-deleted',
            exerciseNameSnapshot: 'Ejercicio anterior',
            muscleGroupSnapshot: 'Glúteos e isquios',
            sets: [
              WorkoutSet(weight: 40, reps: 8, completed: true),
            ],
          ),
        ],
      ),
    ];
  }
}

void main() {
  testWidgets('opens on-device history audit read-only at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseListProvider.overrideWith(_Catalog.new),
          routineListProvider.overrideWith(_Routines.new),
          workoutHistoryProvider.overrideWith(_History.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MuscleHeatmapGrid()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open_anatomy_audit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open_anatomy_audit')));
    await tester.pumpAndSettle();
    expect(find.text('Revisión anatómica'), findsOneWidget);
    expect(find.text('Diagnóstico de este dispositivo'), findsOneWidget);
    expect(find.text('Glúteos e isquios'), findsOneWidget);
    expect(find.text('Tríceps y hombro'), findsOneWidget);
    expect(find.text('Etiquetas generales'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('anatomy_audit_backups')), 120,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('anatomy_audit_backups')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('anatomy_audit_backups')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
