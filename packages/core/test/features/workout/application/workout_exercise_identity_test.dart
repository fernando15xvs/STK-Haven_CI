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
    temp = await Directory.systemTemp.createTemp('stk_identity_');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(HiveBoxes.activeWorkout);
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  WorkoutExercise exercise(String instanceId, double weight) => WorkoutExercise(
    instanceId: instanceId,
    exerciseId: 'press',
    exerciseNameSnapshot: 'Press',
    muscleGroupSnapshot: 'Pecho',
    sets: [WorkoutSet(weight: weight, reps: 10, completed: false)],
  );

  WorkoutSession draft(List<WorkoutExercise> exercises) {
    final now = DateTime(2026, 11, 13, 10);
    return WorkoutSession(
      id: 'duplicates', routineNameSnapshot: 'Upper',
      startedAt: now, finishedAt: now, durationSeconds: 0,
      exercises: exercises,
    );
  }

  test('copyWith retains instance ID when editing sets', () {
    final first = exercise('one', 20);
    final edited = first.copyWith(sets: [first.sets.single.copyWith(weight: 22)]);
    expect(edited.instanceId, 'one');
    expect(edited.exerciseId, 'press');
    expect(edited.sets.single.weight, 22);
  });

  test('duplicate movements retain their own weights and IDs on reorder', () async {
    await box.clear();
    final repository = ActiveWorkoutRepository(box);
    await repository.saveDraft(draft([exercise('one', 20), exercise('two', 40)]));
    final container = ProviderContainer();
    final before = container.read(activeWorkoutProvider).session!.exercises;
    expect(before.map((e) => e.exerciseId).toSet(), {'press'});
    expect(before.map((e) => e.instanceId).toSet(), {'one', 'two'});
    container.read(activeWorkoutProvider.notifier).reorderExercises(0, 2);
    final after = container.read(activeWorkoutProvider).session!.exercises;
    expect(after.map((e) => e.instanceId).toList(), ['two', 'one']);
    expect(after.map((e) => e.sets.single.weight).toList(), [40, 20]);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(repository.getDraft()!.exercises.map((e) => e.instanceId).toList(),
        ['two', 'one']);
    container.dispose();
  });

  test('legacy drafts without instance IDs are upgraded non-destructively', () async {
    await box.clear();
    final repository = ActiveWorkoutRepository(box);
    await repository.saveDraft(draft([exercise('', 20), exercise('', 40)]));
    final payload = Map<dynamic, dynamic>.from(box.get('draft') as Map);
    payload['exercises'] = (payload['exercises'] as List).map((value) {
      final old = Map<dynamic, dynamic>.from(value as Map);
      old.remove('instanceId');
      return old;
    }).toList();
    await box.put('draft', payload);
    final loaded = repository.getDraft()!;
    expect(loaded.exercises.every((e) => e.instanceId.isNotEmpty), isTrue);
    expect(loaded.exercises.map((e) => e.instanceId).toSet(), hasLength(2));
    expect(loaded.exercises.map((e) => e.sets.single.weight).toList(), [20, 40]);
    await repository.saveDraft(loaded);
    expect(repository.getDraft()!.exercises.map((e) => e.instanceId).toList(),
        loaded.exercises.map((e) => e.instanceId).toList());
  });
}
