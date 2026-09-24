import 'package:core/domain/models/habit_study_timer.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:hive/hive.dart';

class HabitTaskRepository {
  static const String taskPrefix = 'task::';
  static const String completionPrefix = 'completion::';
  static const String runtimePrefix = 'runtime::';
  static const String activeStudyTimerKey = 'runtime::study_timer';

  final Box<dynamic> _box;

  HabitTaskRepository(this._box);

  List<HabitTask> getTasks({bool includeArchived = false}) {
    final tasks = <HabitTask>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(taskPrefix)) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final task = HabitTask.fromJson(Map<String, dynamic>.from(raw));
        if (task.id.isEmpty || task.title.isEmpty) continue;
        if (!includeArchived && task.archived) continue;
        tasks.add(task);
      } catch (_) {
        // Ignore malformed local entries rather than breaking the whole list.
      }
    }
    tasks.sort((a, b) {
      final byArchived = a.archived == b.archived
          ? 0
          : (a.archived ? 1 : -1);
      if (byArchived != 0) return byArchived;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return tasks;
  }

  HabitTask? getTask(String id) {
    final raw = _box.get('$taskPrefix$id');
    if (raw is! Map) return null;
    try {
      final task = HabitTask.fromJson(Map<String, dynamic>.from(raw));
      return task.id.isEmpty ? null : task;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTask(HabitTask task) async {
    if (task.id.trim().isEmpty) {
      throw ArgumentError.value(task.id, 'task.id', 'No puede estar vacío.');
    }
    if (task.title.trim().isEmpty) {
      throw ArgumentError.value(
        task.title,
        'task.title',
        'No puede estar vacío.',
      );
    }
    await _box.put('$taskPrefix${task.id}', task.toJson());
  }

  Future<void> archiveTask(String id, {required DateTime updatedAt}) async {
    final task = getTask(id);
    if (task == null) return;
    await saveTask(
      task.copyWith(
        archived: true,
        updatedAt: updatedAt,
      ),
    );
  }

  List<HabitTaskCompletion> getCompletions({String? taskId}) {
    final items = <HabitTaskCompletion>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(completionPrefix)) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final completion = HabitTaskCompletion.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (completion.id.isEmpty || completion.taskId.isEmpty) continue;
        if (taskId != null && completion.taskId != taskId) continue;
        items.add(completion);
      } catch (_) {
        // Ignore malformed completion entries.
      }
    }
    items.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return items;
  }

  Future<void> saveCompletion(HabitTaskCompletion completion) async {
    if (completion.id.trim().isEmpty || completion.taskId.trim().isEmpty) {
      throw ArgumentError('Completion id y taskId son obligatorios.');
    }
    await _box.put(
      '$completionPrefix${completion.id}',
      completion.toJson(),
    );
  }

  Future<void> deleteCompletion(String id) async {
    await _box.delete('$completionPrefix$id');
  }

  HabitStudyTimerState? getActiveStudyTimer() {
    final raw = _box.get(activeStudyTimerKey);
    if (raw is! Map) return null;
    try {
      final timer = HabitStudyTimerState.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return timer.taskId.isEmpty ? null : timer;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveStudyTimer(HabitStudyTimerState timer) {
    return _box.put(activeStudyTimerKey, timer.toJson());
  }

  Future<void> clearActiveStudyTimer() {
    return _box.delete(activeStudyTimerKey);
  }

  Future<void> clearAll() => _box.clear();
}
