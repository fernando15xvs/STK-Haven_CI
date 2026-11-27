import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/habit_task.dart';
import 'habit_integrity_policy.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_task_notification_service.dart';
import 'package:core/features/habits/data/habit_task_repository.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';
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
    String sourceReference = '',
    int? weeklyGoal,
    double? targetQuantity,String quantityUnit='',
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
      sourceReference: sourceReference,
      weeklyGoal: weeklyGoal?.clamp(1,7).toInt(),
      targetQuantity:targetQuantity!=null&&targetQuantity.isFinite&&targetQuantity>0?targetQuantity:null,
      quantityUnit:quantityUnit.trim(),
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
      sourceReference: template.key.isEmpty?'':'template:${template.key}',
    );
  }

  final Map<String,Future<HabitTask>> _templateWrites={};
  Future<HabitTask> ensureTemplate(HabitTaskTemplate template) {
    final key=template.key.isEmpty?template.title:template.key;
    final current=_templateWrites[key];
    if(current!=null)return current;
    final operation=_ensureTemplate(template);
    _templateWrites[key]=operation;
    return operation.whenComplete(()=>_templateWrites.remove(key));
  }
  Future<HabitTask> _ensureTemplate(HabitTaskTemplate template) async {
    final identity='template:${template.key}';
    for(final task in _repository.getTasks()){
      if(task.source==HabitTaskSource.coach)continue;
      if((template.key.isNotEmpty&&task.sourceReference==identity)||
         (task.sourceReference.isEmpty&&task.title==template.title&&task.category==template.category&&task.type==template.type)){
        if(template.key.isEmpty||task.sourceReference==identity)return task;
        final migrated=task.copyWith(sourceReference:identity);
        await _repository.saveTask(migrated);refresh();return migrated;
      }
    }
    return createFromTemplate(template);
  }

  Future<void> updateTask(HabitTask task) async {
    final next=task.copyWith(updatedAt: DateTime.now());
    await _repository.saveTask(next);
    if(next.source!=HabitTaskSource.coach&&next.reminderEnabled){
      final ok=await HabitTaskNotificationService.scheduleNext(next,requestPermissionIfNeeded:false);
      if(!ok)await _repository.saveTask(next.copyWith(reminderEnabled:false));
    }
    refresh();
  }

  Future<bool> setReminder({
    required String taskId,
    required bool enabled,
    DateTime? scheduledAt,
  }) async {
    final task = _repository.getTask(taskId);
    if (task == null || task.source == HabitTaskSource.coach) return false;

    if (!enabled) {
      await HabitTaskNotificationService.cancel(taskId);
      await _repository.saveTask(
        task.copyWith(
          reminderEnabled: false,
          updatedAt: DateTime.now(),
        ),
      );
      refresh();
      return true;
    }

    final updated = task.copyWith(
      reminderEnabled: true,
      scheduledAt: scheduledAt ?? task.scheduledAt,
      updatedAt: DateTime.now(),
    );
    final scheduled = await HabitTaskNotificationService.scheduleNext(updated);
    await _repository.saveTask(
      updated.copyWith(
        reminderEnabled: scheduled,
        updatedAt: DateTime.now(),
      ),
    );
    refresh();
    return scheduled;
  }

  Future<void> archiveTask(String taskId) async {
    final task = _repository.getTask(taskId);
    if (task == null || task.source == HabitTaskSource.coach) return;
    if(_repository.getActiveStudyTimer()?.taskId==taskId)throw StateError('Finaliza o descarta la sesión activa primero');
    await HabitTaskNotificationService.cancel(taskId);
    await _repository.saveTask(task.copyWith(reminderEnabled:false));
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
    String? completionId,
    double? quantity,
  }) async {
    final time=completedAt ?? DateTime.now();
    final task=_repository.getTask(taskId);
    if(task==null || task.archived) throw StateError('Hábito no disponible');
    if(quantity!=null&&(!quantity.isFinite||quantity<=0))throw ArgumentError('Cantidad inválida');
    final existing=_repository.getCompletions(taskId:taskId);
    for(final row in existing){
      if(row.id==completionId || (task.type==HabitTaskType.checklist && HabitIntegrityPolicy.day(row.completedAt)==HabitIntegrityPolicy.day(time))) return row;
    }
    final completion = HabitTaskCompletion(
      id: completionId ?? (task.type==HabitTaskType.checklist ? 'daily:${taskId}:${HabitIntegrityPolicy.day(time).toIso8601String()}' : _uuid.v4()),
      taskId: taskId,
      completedAt: time,
      minutesSpent: minutesSpent.clamp(0, 1440).toInt(),
      quantity:quantity,
      note: note.trim(),
      status: status,
    );
    await _repository.saveCompletion(completion);
    refresh();
    return completion;
  }

  final Set<String> _homeWrites = {};

  /// Quick checklist uses existing task/completion storage. Timed tasks are
  /// opened in the dedicated screen; a checkbox must never invent minutes.
  Future<void> setHomeChecklist(String taskId, bool completed, DateTime now) async {
    if (!_homeWrites.add(taskId)) return;
    try {
      final task = _repository.getTask(taskId);
      final profile = ref.read(userExperienceProfileProvider).value;
      if (task == null || task.archived || task.type != HabitTaskType.checklist ||
          task.targetMinutes != 0 || task.source == HabitTaskSource.coach ||
          profile?.habitsEnabled != true || (task.faithSpecific && profile?.faithEnabled != true) ||
          !HabitScheduleService.isDueOn(task, now)) {
        throw StateError('Este hábito se gestiona en Hábitos y lectura.');
      }
      final today = DateTime(now.year, now.month, now.day);
      final matches = _repository.getCompletions(taskId: taskId).where((c) {
        final date = c.completedAt.toLocal();
        return DateTime(date.year, date.month, date.day) == today;
      }).toList();
      if (matches.any((c) => c.status == HabitTaskCompletionStatus.skipped)) {
        throw StateError('Revisa esta tarea desde Hábitos y lectura.');
      }
      if (completed && matches.isEmpty) {
        await completeTask(taskId: taskId, completedAt: now);
      } else if (!completed) {
        for (final completion in matches) {
          await _repository.deleteCompletion(completion.id);
        }
        refresh();
      }
    } finally {
      _homeWrites.remove(taskId);
    }
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
            HabitIntegrityPolicy.pending(task, completions, today),
      )
      .toList(growable: false);
});
