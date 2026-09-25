import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/data/habit_task_repository.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class HabitTasksState {
  final List<HabitTask> tasks;
  final List<HabitTaskCompletion> completions;

  const HabitTasksState({
    this.tasks = const <HabitTask>[],
    this.completions = const <HabitTaskCompletion>[],
  });

  HabitTasksState copyWith({
    List<HabitTask>? tasks,
    List<HabitTaskCompletion>? completions,
  }) {
    return HabitTasksState(
      tasks: tasks ?? this.tasks,
      completions: completions ?? this.completions,
    );
  }
}

final habitTaskRepositoryProvider = Provider<HabitTaskRepository>((ref) {
  return HabitTaskRepository(Hive.box<dynamic>(HiveBoxes.habitTasks));
});

final habitTasksProvider =
    NotifierProvider<HabitTasksNotifier, HabitTasksState>(
  HabitTasksNotifier.new,
);

class HabitTasksNotifier extends Notifier<HabitTasksState> {
  static const Uuid _uuid = Uuid();
  late final HabitTaskRepository _repository;

  @override
  HabitTasksState build() {
    _repository = ref.watch(habitTaskRepositoryProvider);
    return _load();
  }

  HabitTasksState _load() {
    return HabitTasksState(
      tasks: _repository.getTasks(),
      completions: _repository.getCompletions(),
    );
  }

  void refresh() {
    state = _load();
  }

  Future<HabitTask> createTask({
    required String title,
    String category = 'General',
    HabitTaskType type = HabitTaskType.checklist,
    int targetMinutes = 0,
    HabitRecurrenceType recurrence = HabitRecurrenceType.once,
    Set<int> weekdays = const <int>{},
    DateTime? scheduledAt,
    HabitTaskSource source = HabitTaskSource.user,
    HabitTaskVisibility visibility = HabitTaskVisibility.private,
    bool faithSpecific = false,
    String reference = '',
    String notes = '',
  }) async {
    final now = DateTime.now();
    final task = HabitTask(
      id: _uuid.v4(),
      title: title.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      type: type,
      targetMinutes: targetMinutes.clamp(0, 1440).toInt(),
      recurrence: recurrence,
      weekdays: Set<int>.from(weekdays),
      scheduledAt: scheduledAt,
      createdAt: now,
      updatedAt: now,
      source: source,
      visibility: visibility,
      faithSpecific: faithSpecific,
      reference: reference.trim(),
      notes: notes.trim(),
    );
    await _repository.saveTask(task);
    refresh();
    return task;
  }

  Future<HabitTask> createFromTemplate(
    HabitTaskTemplate template, {
    DateTime? scheduledAt,
    HabitTaskSource source = HabitTaskSource.user,
  }) {
    return createTask(
      title: template.title,
      category: template.category,
      type: template.type,
      targetMinutes: template.targetMinutes,
      recurrence: template.recurrence,
      weekdays: template.weekdays,
      scheduledAt: scheduledAt,
      source: source,
      faithSpecific: template.faithSpecific,
      reference: template.reference,
      notes: template.notes,
    );
  }

  Future<void> updateTask(HabitTask task) async {
    await _repository.saveTask(
      task.copyWith(updatedAt: DateTime.now()),
    );
    refresh();
  }

  Future<void> archiveTask(String taskId) async {
    await _repository.archiveTask(
      taskId,
      updatedAt: DateTime.now(),
    );
    refresh();
  }

  Future<HabitTaskCompletion> completeTask({
    required String taskId,
    int minutesSpent = 0,
    String note = '',
    HabitTaskCompletionStatus status = HabitTaskCompletionStatus.completed,
    DateTime? completedAt,
  }) async {
    final completion = HabitTaskCompletion(
      id: _uuid.v4(),
      taskId: taskId,
      completedAt: completedAt ?? DateTime.now(),
      minutesSpent: minutesSpent.clamp(0, 1440).toInt(),
      note: note.trim(),
      status: status,
    );
    await _repository.saveCompletion(completion);
    refresh();
    return completion;
  }

  Future<void> undoCompletion(String completionId) async {
    await _repository.deleteCompletion(completionId);
    refresh();
  }

  List<HabitTaskCompletion> completionsFor(String taskId) {
    return state.completions
        .where((item) => item.taskId == taskId)
        .toList(growable: false);
  }
}


final visibleHabitTasksProvider = Provider<List<HabitTask>>((ref) {
  final state = ref.watch(habitTasksProvider);
  final faithEnabled = ref.watch(
    userExperienceProfileProvider.select(
      (profile) => profile.value?.faithEnabled ?? false,
    ),
  );
  return state.tasks
      .where((task) => !task.faithSpecific || faithEnabled)
      .toList(growable: false);
});

final dueHabitTasksTodayProvider = Provider<List<HabitTask>>((ref) {
  final tasks = ref.watch(visibleHabitTasksProvider);
  final completions = ref.watch(
    habitTasksProvider.select((state) => state.completions),
  );
  final today = DateTime.now();

  return tasks
      .where(
        (task) =>
            HabitScheduleService.isDueOn(task, today) &&
            !HabitScheduleService.isResolvedOn(task, completions, today),
      )
      .toList(growable: false);
});
