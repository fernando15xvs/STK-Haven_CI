import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Programs extends TrainingProgramListNotifier {
  @override
  List<TrainingProgram> build() {
    final now = DateTime.now();
    return [
      TrainingProgram(
        id: 'p', name: 'Programa semanal',
        routineIds: const ['r'],
        createdAt: now,
        startedAt: now.subtract(const Duration(days: 1)),
        scheduleMode: ProgramScheduleMode.continuous,
        targetSessionsPerWeek: 1,
        trainingWeekdays: const {DateTime.monday},
        isActive: false,
      ),
    ];
  }

  @override
  Future<TrainingProgram?> reconcileActive() async => null;
}

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => [
    Routine(
      id: 'r', name: 'Upper A',
      scheduledDays: const [DateTime.monday],
      createdAt: DateTime(2026, 9, 1),
      exercises: const [
        RoutineExercise(
          exerciseId: 'bench', order: 0, targetSets: 3,
          targetRepsMin: 8, targetRepsMax: 12, restSeconds: 90,
        ),
      ],
    ),
  ];
}

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => [
    Exercise(id: 'bench', name: 'Press banca', muscleGroup: 'Pecho'),
  ];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() => [];
}

void main() {
  testWidgets('320 px plan leaves weekly volume uncovered and labels units',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        trainingProgramListProvider.overrideWith(_Programs.new),
        routineListProvider.overrideWith(_Routines.new),
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_History.new),
      ],
      child: const MaterialApp(home: TrainingProgramsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('create_training_plan')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Volumen de esta semana'), 140);
    await tester.tap(find.text('Volumen de esta semana'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('series efectivas (realizadas/previstas)'), 120,
    );
    expect(find.textContaining('kg·rep'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
