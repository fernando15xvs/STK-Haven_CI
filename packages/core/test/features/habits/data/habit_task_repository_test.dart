import 'dart:io';

import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/data/habit_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('stk_haven_habit_tasks_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('habit_tasks_repository_test');
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('HabitTaskRepository', () {
    final now = DateTime(2026, 9, 24, 9);

    HabitTask task(String id, {bool archived = false}) => HabitTask(
          id: id,
          title: 'Tarea $id',
          createdAt: now,
          updatedAt: now,
          archived: archived,
        );

    test('stores and loads tasks without Hive adapters', () async {
      final repository = HabitTaskRepository(box);

      await repository.saveTask(task('a'));
      await repository.saveTask(task('b'));

      expect(repository.getTasks().map((item) => item.id).toSet(), {'a', 'b'});
      expect(repository.getTask('a')?.title, 'Tarea a');
    });

    test('archived tasks are hidden unless explicitly requested', () async {
      final repository = HabitTaskRepository(box);
      await repository.saveTask(task('active'));
      await repository.saveTask(task('archived', archived: true));

      expect(repository.getTasks().map((item) => item.id), ['active']);
      expect(
        repository.getTasks(includeArchived: true).map((item) => item.id).toSet(),
        {'active', 'archived'},
      );
    });

    test('completion history is filterable by task', () async {
      final repository = HabitTaskRepository(box);
      await repository.saveCompletion(
        HabitTaskCompletion(
          id: 'c1',
          taskId: 'a',
          completedAt: now,
          minutesSpent: 10,
        ),
      );
      await repository.saveCompletion(
        HabitTaskCompletion(
          id: 'c2',
          taskId: 'b',
          completedAt: now.add(const Duration(hours: 1)),
        ),
      );

      final a = repository.getCompletions(taskId: 'a');

      expect(a, hasLength(1));
      expect(a.single.id, 'c1');
      expect(a.single.minutesSpent, 10);
    });

    test('malformed entries do not break valid task list', () async {
      final repository = HabitTaskRepository(box);
      await repository.saveTask(task('valid'));
      await box.put('${HabitTaskRepository.taskPrefix}bad', 'not a map');

      expect(repository.getTasks().map((item) => item.id), ['valid']);
    });
  });
}
