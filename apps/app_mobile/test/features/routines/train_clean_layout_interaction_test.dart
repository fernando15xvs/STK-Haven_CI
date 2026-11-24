import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/providers/exercise_provider.dart';
import 'package:core/features/programs/application/providers/training_program_provider.dart';
import 'package:core/features/routines/application/providers/routine_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/presentation/pages/routines_page.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/next_training_session_hero.dart';
import 'package:intl/date_symbol_data_local.dart';

final _routines = List<Routine>.generate(
  5,
  (index) => Routine(
    id: 'r$index',
    name: 'Rutina $index',
    scheduledDays: const [],
    exercises: const [],
    createdAt: DateTime(2026, 11, 21),
  ),
);

final _program = TrainingProgram(
  id: 'test-plan',
  name: 'STK',
  routineIds: _routines.map((routine) => routine.id).toList(),
  createdAt: DateTime(2026, 11, 21),
  startedAt: DateTime(2026, 11, 21),
  scheduleMode: ProgramScheduleMode.flexible,
  targetSessionsPerWeek: 4,
);

final _suggested = NextProgramSession(
  program: _program,
  routine: _routines.first,
  week: 1,
  isDeloadWeek: false,
  isTrainingDay: true,
  trainingWeekdays: const {},
  scheduledDate: null,
  targetSessionsPerWeek: 4,
);

class _Routines extends RoutineListNotifier {
  @override
  List<Routine> build() => _routines;
}

class _Exercises extends ExerciseListNotifier {
  @override
  List<Exercise> build() => const [];
}

class _History extends WorkoutHistoryNotifier {
  @override
  List<WorkoutSession> build() => const [];
}

class _Programs extends TrainingProgramListNotifier {
  @override
  List<TrainingProgram> build() => [_program];
}

class _NoPrograms extends TrainingProgramListNotifier {
  @override
  List<TrainingProgram> build() => const [];
}

class _NoWorkout extends ActiveWorkoutNotifier {
  @override
  ActiveWorkoutState build() => const ActiveWorkoutState();
}

class _ActiveWorkout extends ActiveWorkoutNotifier {
  @override
  ActiveWorkoutState build() => ActiveWorkoutState(
        session: WorkoutSession(
          id: 'preserved-active-session',
          routineId: 'r0',
          routineNameSnapshot: 'Rutina 0 activa',
          startedAt: DateTime.now().subtract(const Duration(minutes: 8)),
          finishedAt: DateTime.now(),
          durationSeconds: 480,
          exercises: const [],
        ),
      );
}

Future<void> _pumpTrain(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.dark,
  bool active = false,
  bool hasProgram = true,
}) async {
  tester.view.physicalSize = Size(width, 1280);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routineListProvider.overrideWith(_Routines.new),
        exerciseListProvider.overrideWith(_Exercises.new),
        workoutHistoryProvider.overrideWith(_History.new),
        trainingProgramListProvider.overrideWith(
          hasProgram ? _Programs.new : _NoPrograms.new,
        ),
        activeTrainingProgramProvider.overrideWith(
          (ref) => hasProgram ? _program : null,
        ),
        nextProgramSessionProvider.overrideWith(
          (ref) => hasProgram ? _suggested : null,
        ),
        legacyTodaySessionProvider.overrideWith((ref) => null),
        activeWorkoutProvider.overrideWith(
          active ? _ActiveWorkout.new : _NoWorkout.new,
        ),
        activeWorkoutLastActivityProvider.overrideWith(
          (ref) => DateTime.now(),
        ),
      ],
      child: MaterialApp(
        theme: AppearanceTheme.build(
          const AppearanceSettings(),
          brightness,
        ),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const RoutinesPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Entrenar keeps one featured session and usable links at $width / $scale',
        (tester) async {
          await _pumpTrain(tester, width: width, scale: scale);
          expect(find.byKey(const ValueKey('train_next_session_hero')), findsOneWidget);
          expect(find.byKey(const ValueKey('train_start_next_session')), findsOneWidget);
          expect(find.text('Rutina 0'), findsOneWidget);
          expect(find.byKey(const ValueKey('train_routine_r0')), findsNothing);
          expect(find.byKey(const ValueKey('train_open_planning')), findsOneWidget);
          expect(find.byKey(const ValueKey('train_open_manage')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Ver todas reveals the highlighted routine and all saved routines',
      (tester) async {
    await _pumpTrain(tester);
    expect(find.byKey(const ValueKey('train_routine_r0')), findsNothing);
    expect(find.byKey(const ValueKey('train_routine_r4')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('train_show_all_routines')),
      180,
    );
    await tester.tap(find.byKey(const ValueKey('train_show_all_routines')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('train_routine_r4')),
      180,
    );
    expect(find.byKey(const ValueKey('train_routine_r4')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('train_routine_r0')),
      -180,
    );
    expect(find.byKey(const ValueKey('train_routine_r0')), findsOneWidget);
    expect(find.byKey(const ValueKey('train_show_all_routines')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active workout is the only primary action; other starts stay hidden',
      (tester) async {
    await _pumpTrain(tester, active: true);
    expect(find.byKey(const ValueKey('train_resume_workout')), findsOneWidget);
    expect(find.byKey(const ValueKey('train_start_next_session')), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
    expect(find.byKey(const ValueKey('train_routine_r0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gestionar keeps all three routes and hides Crear plan for active plan',
      (tester) async {
    await _pumpTrain(tester);
    await tester.tap(find.byKey(const ValueKey('train_open_manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('train_manage_programs')), findsOneWidget);
    expect(find.byKey(const ValueKey('train_manage_routine_templates')), findsOneWidget);
    expect(find.byKey(const ValueKey('train_manage_program_templates')), findsOneWidget);
    expect(find.byKey(const ValueKey('train_create_plan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gestionar offers Crear plan when saved routines have no program',
      (tester) async {
    await _pumpTrain(tester, hasProgram: false);
    expect(find.byKey(const ValueKey('train_next_session_hero')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('train_open_manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('train_create_plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
