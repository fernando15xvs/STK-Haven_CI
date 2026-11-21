import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/next_training_session_hero.dart';

class _NoActiveWorkout extends ActiveWorkoutNotifier {
  @override
  ActiveWorkoutState build() => const ActiveWorkoutState();
}

class _WithActiveWorkout extends ActiveWorkoutNotifier {
  @override
  ActiveWorkoutState build() => ActiveWorkoutState(
        session: WorkoutSession(
          id: 'session-preserved-001',
          routineId: 'existing-upper-b',
          routineNameSnapshot: 'Upper B · sesión activa',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          finishedAt: DateTime.now(),
          exercises: const [],
          durationSeconds: 600,
        ),
      );
}

void main() {
  final now = DateTime(2026, 11, 21);
  final routine = Routine(
    id: 'existing-upper-b',
    name: 'Upper B',
    scheduledDays: const [1, 3, 5],
    exercises: const [
      RoutineExercise(
        exerciseId: 'shoulder-1',
        order: 0,
        targetSets: 3,
        targetRepsMin: 8,
        targetRepsMax: 12,
        restSeconds: 90,
      ),
    ],
    createdAt: now,
  );
  final program = TrainingProgram(
    id: 'existing-program',
    name: 'STK',
    routineIds: [routine.id],
    createdAt: now,
    startedAt: now,
    scheduleMode: ProgramScheduleMode.flexible,
    targetSessionsPerWeek: 4,
  );
  final suggested = NextProgramSession(
    program: program,
    routine: routine,
    week: 1,
    isDeloadWeek: false,
    isTrainingDay: true,
    trainingWeekdays: const {},
    scheduledDate: null,
    targetSessionsPerWeek: 4,
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('next workout hero fits ${width.toInt()}dp at $scale text ($brightness)',
          (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            activeWorkoutProvider.overrideWith(_NoActiveWorkout.new),
            nextProgramSessionProvider.overrideWith((ref) => suggested),
            activeTrainingProgramProvider.overrideWith((ref) => program),
            legacyTodaySessionProvider.overrideWith((ref) => null),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                  child: NextTrainingSessionHero(
                    routines: [routine],
                    historyByRoutine: const {},
                    musclesFor: (_) => const ['Hombros', 'Espalda'],
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('train_next_session_hero')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('train_start_next_session')),
            findsOneWidget);
        expect(find.text('Upper B'), findsOneWidget);
        expect(find.text('Rotación flexible · sin día obligatorio'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      }
    }
  }

  testWidgets('active session wins over projected workout and opens no new Start',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeWorkoutProvider.overrideWith(_WithActiveWorkout.new),
        activeWorkoutLastActivityProvider.overrideWith(
          (ref) => DateTime.now(),
        ),
        nextProgramSessionProvider.overrideWith((ref) => suggested),
        activeTrainingProgramProvider.overrideWith((ref) => program),
        legacyTodaySessionProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NextTrainingSessionHero(
            routines: [routine],
            historyByRoutine: const {},
            musclesFor: (_) => const ['Hombros'],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('train_next_session_hero')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('train_resume_workout')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('train_start_next_session')),
        findsNothing);
    expect(find.text('Upper B · sesión activa'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive day uses projected date, never today eligibility',
      (tester) async {
    final fixedProgram = TrainingProgram(
      id: 'fixed-plan',
      name: 'Semana fija',
      routineIds: [routine.id],
      createdAt: now,
      startedAt: now,
      scheduleMode: ProgramScheduleMode.fixed,
      fixedWeekdayRoutineIds: {DateTime.monday: routine.id},
    );
    final futureSession = NextProgramSession(
      program: fixedProgram,
      routine: routine,
      week: 1,
      isDeloadWeek: false,
      isTrainingDay: true, // Historically this caused the incorrect label.
      trainingWeekdays: const {DateTime.monday},
      scheduledDate: DateTime.now().add(const Duration(days: 14)),
      targetSessionsPerWeek: 1,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeWorkoutProvider.overrideWith(_NoActiveWorkout.new),
        nextProgramSessionProvider.overrideWith((ref) => futureSession),
        activeTrainingProgramProvider.overrideWith((ref) => fixedProgram),
        legacyTodaySessionProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NextTrainingSessionHero(
            routines: [routine],
            historyByRoutine: const {},
            musclesFor: (_) => const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Próximo día:'), findsOneWidget);
    expect(find.text('Sesión programada para hoy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused plan is not recommended as active workout', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeWorkoutProvider.overrideWith(_NoActiveWorkout.new),
        nextProgramSessionProvider.overrideWith((ref) => null),
        activeTrainingProgramProvider.overrideWith((ref) => null),
        legacyTodaySessionProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NextTrainingSessionHero(
            routines: [routine],
            historyByRoutine: const {},
            musclesFor: (_) => const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('train_next_session_hero')),
        findsNothing);
    expect(find.byKey(const ValueKey('train_choose_routine')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no program and no routines does not invent a session',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeWorkoutProvider.overrideWith(_NoActiveWorkout.new),
        nextProgramSessionProvider.overrideWith((ref) => null),
        activeTrainingProgramProvider.overrideWith((ref) => null),
        legacyTodaySessionProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: NextTrainingSessionHero(
            routines: [],
            historyByRoutine: {},
            musclesFor: _noMuscles,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('train_next_session_hero')),
        findsNothing);
    expect(find.byKey(const ValueKey('train_choose_routine')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<String> _noMuscles(Routine routine) => const [];
