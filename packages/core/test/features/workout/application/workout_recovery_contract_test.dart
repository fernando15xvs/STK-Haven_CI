import 'dart:io';

import 'package:core/database/hive/hive_adapters.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/database/hive/models/hive_routine.dart';
import 'package:core/database/hive/models/hive_workout_session.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/data/active_workout_repository.dart';
import 'package:core/features/workout/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> activeWorkoutBox;
  late Box<HiveWorkoutSession> historyBox;
  late Box<HiveRoutine> routinesBox;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'stk_haven_workout_recovery_',
    );
    Hive.init(tempDirectory.path);
    registerHiveAdapters();
    activeWorkoutBox = await Hive.openBox<dynamic>(HiveBoxes.activeWorkout);
    historyBox = await Hive.openBox<HiveWorkoutSession>(
      'workout_recovery_history_test',
    );
    routinesBox = await Hive.openBox<HiveRoutine>(
      'workout_recovery_routines_test',
    );
  });

  setUp(() async {
    await activeWorkoutBox.clear();
    await historyBox.clear();
    await routinesBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'incomplete workout draft reopens with the same session id and progress',
    () async {
      final incomplete = _session(complete: false);
      await ActiveWorkoutRepository(activeWorkoutBox).saveDraft(incomplete);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final resumed = container.read(activeWorkoutProvider);
      expect(resumed.session, isNotNull);
      expect(resumed.session!.id, incomplete.id);
      expect(resumed.session!.routineId, incomplete.routineId);
      expect(resumed.globalTimerSeconds, greaterThanOrEqualTo(0));
      expect(
        resumed.session!.exercises.single.sets.map((set) => set.completed),
        [true, false],
      );

      final persisted = ActiveWorkoutRepository(activeWorkoutBox).getDraft();
      expect(persisted, isNotNull);
      expect(persisted!.id, incomplete.id);
      expect(persisted.exercises.single.sets.map((set) => set.completed), [
        true,
        false,
      ]);
    },
  );

  test(
    'completing a resumed session replaces history and advances once',
    () async {
      final repository = WorkoutRepository(historyBox);
      final partial = _session(complete: false);
      final completed = _session(complete: true);
      final program = TrainingProgram(
        id: 'program',
        name: 'Upper / Lower',
        routineIds: const ['upper-a', 'lower-a'],
        createdAt: DateTime(2026, 9, 1),
        startedAt: DateTime(2026, 9, 1),
        durationWeeks: 8,
      );

      await repository.saveWorkoutSession(partial);
      final beforeCompletion = repository.getAllSessions();
      expect(beforeCompletion, hasLength(1));
      expect(
        ProgramRotationCoordinator.reconcile(
          program,
          beforeCompletion,
        ).completions,
        isEmpty,
      );

      await repository.saveWorkoutSession(completed);
      final afterCompletion = repository.getAllSessions();
      expect(afterCompletion, hasLength(1));
      expect(afterCompletion.single.id, partial.id);
      expect(
        afterCompletion.single.exercises.single.sets.every(
          (set) => set.completed,
        ),
        isTrue,
      );

      final reconciled = ProgramRotationCoordinator.reconcile(
        program,
        afterCompletion,
      );
      expect(reconciled.completions, hasLength(1));
      expect(reconciled.completions.single.workoutSessionId, partial.id);
      expect(reconciled.nextRoutineId, 'lower-a');

      final replayed = ProgramRotationCoordinator.reconcile(
        reconciled,
        afterCompletion,
      );
      expect(replayed.completions, hasLength(1));
      expect(replayed.nextRoutineId, 'lower-a');
    },
  );

  test('legacy routine exercise without phase loads as main', () async {
    final legacyExercise = HiveRoutineExercise(
      exerciseId: 'bench-press',
      order: 0,
      targetSets: 3,
      targetRepsMin: 8,
      targetRepsMax: 12,
      restSeconds: 120,
    );
    expect(legacyExercise.phase, 'main');

    await routinesBox.put(
      'legacy-routine',
      HiveRoutine(
        id: 'legacy-routine',
        name: 'Legacy',
        scheduledDays: const [],
        exercises: [legacyExercise],
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final routine = RoutineRepository(routinesBox).getAllRoutines().single;
    expect(routine.exercises.single.phase, RoutineExercisePhase.main);
  });
}

WorkoutSession _session({required bool complete}) {
  final startedAt = DateTime(2026, 9, 20, 8);
  return WorkoutSession(
    id: 'resumable-session',
    routineId: 'upper-a',
    routineNameSnapshot: 'Upper A',
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 10)),
    durationSeconds: 600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'bench-press',
        exerciseNameSnapshot: 'Press banca',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          const WorkoutSet(
            weight: 60,
            reps: 10,
            completed: true,
            setType: WorkoutSetType.working,
          ),
          WorkoutSet(
            weight: 60,
            reps: complete ? 10 : 0,
            completed: complete,
            setType: WorkoutSetType.working,
          ),
        ],
      ),
    ],
  );
}
