import 'dart:io';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/data/active_workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory temp;
  late Box<dynamic> box;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('stk_set_delete_');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(HiveBoxes.activeWorkout);
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('deleting warmup never transfers its weight or reps to working sets',
      () async {
    await box.clear();
    final started = DateTime(2026, 10, 10);
    await ActiveWorkoutRepository(box).saveDraft(WorkoutSession(
      id: 'workout-delete-case',
      routineId: 'routine-a',
      routineNameSnapshot: 'Rutina',
      startedAt: started,
      finishedAt: started,
      durationSeconds: 0,
      exercises: const [
        WorkoutExercise(
          exerciseId: 'pulley',
          exerciseNameSnapshot: 'Polea',
          muscleGroupSnapshot: 'Espalda',
          sets: [
            WorkoutSet(
              weight: 20, reps: 15, completed: false,
              setType: WorkoutSetType.warmup, restSeconds: 30,
            ),
            WorkoutSet(
              weight: 50, reps: 10, completed: false,
              setType: WorkoutSetType.working, restSeconds: 90,
            ),
            WorkoutSet(
              weight: 55, reps: 8, completed: false,
              setType: WorkoutSetType.working, restSeconds: 120,
            ),
          ],
        ),
      ],
    ));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(activeWorkoutProvider).session, isNotNull);
    container.read(activeWorkoutProvider.notifier).removeSet(0, 0);
    final after = container.read(activeWorkoutProvider).session!
        .exercises.single.sets;
    expect(after, hasLength(2));
    expect(after.map((s) => s.setType),
        [WorkoutSetType.working, WorkoutSetType.working]);
    expect(after.map((s) => s.weight), [50, 55]);
    expect(after.map((s) => s.reps), [10, 8]);
    expect(after.map((s) => s.restSeconds), [90, 120]);
    expect(after.every((s) => !s.completed), isTrue);
  });

  test('deleting middle set preserves the following set unchanged', () async {
    await box.clear();
    final started = DateTime(2026, 10, 11);
    await ActiveWorkoutRepository(box).saveDraft(WorkoutSession(
      id: 'workout-middle-case',
      routineNameSnapshot: 'Rutina',
      startedAt: started,
      finishedAt: started,
      durationSeconds: 0,
      exercises: const [
        WorkoutExercise(
          exerciseId: 'press',
          exerciseNameSnapshot: 'Press',
          muscleGroupSnapshot: 'Pecho',
          sets: [
            WorkoutSet(weight: 20, reps: 12, completed: true,
                setType: WorkoutSetType.warmup),
            WorkoutSet(weight: 25, reps: 10, completed: true,
                setType: WorkoutSetType.approach),
            WorkoutSet(weight: 45, reps: 9, completed: true, rir: 2),
          ],
        ),
      ],
    ));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(activeWorkoutProvider.notifier).removeSet(0, 1);
    final after = container.read(activeWorkoutProvider).session!
        .exercises.single.sets;
    expect(after, hasLength(2));
    expect(after.last.weight, 45);
    expect(after.last.reps, 9);
    expect(after.last.rir, 2);
    expect(after.last.completed, isTrue);
  });
}
