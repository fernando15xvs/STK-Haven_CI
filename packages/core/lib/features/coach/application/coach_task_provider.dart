import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/coach/data/coach_task_service.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CoachTaskOperation {
  idle,
  loading,
  assigning,
  completing,
  commenting,
  archiving,
}

class CoachTaskState {
  final List<CoachAssignedTask> tasks;
  final List<CoachTaskOccurrence> occurrences;
  final Map<String, List<CoachTaskComment>> commentsByTask;
  final Map<String, CoachTaskAdherence> adherenceByClient;
  final CoachTaskOperation operation;
  final String? message;
  final bool isError;

  const CoachTaskState({
    this.tasks = const <CoachAssignedTask>[],
    this.occurrences = const <CoachTaskOccurrence>[],
    this.commentsByTask = const <String, List<CoachTaskComment>>{},
    this.adherenceByClient = const <String, CoachTaskAdherence>{},
    this.operation = CoachTaskOperation.idle,
    this.message,
    this.isError = false,
  });

  bool get busy => operation != CoachTaskOperation.idle;

  CoachTaskState copyWith({
    List<CoachAssignedTask>? tasks,
    List<CoachTaskOccurrence>? occurrences,
    Map<String, List<CoachTaskComment>>? commentsByTask,
    Map<String, CoachTaskAdherence>? adherenceByClient,
    CoachTaskOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return CoachTaskState(
      tasks: tasks ?? this.tasks,
      occurrences: occurrences ?? this.occurrences,
      commentsByTask: commentsByTask ?? this.commentsByTask,
      adherenceByClient: adherenceByClient ?? this.adherenceByClient,
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final coachTaskServiceProvider = Provider<CoachTaskService>((ref) {
  return CoachTaskService(Supabase.instance.client);
});

final coachTaskProvider =
    NotifierProvider<CoachTaskNotifier, CoachTaskState>(
  CoachTaskNotifier.new,
);

final coachTaskLazySyncProvider = FutureProvider<void>((ref) async {
  final signedIn = ref.watch(
    appIdentityProvider.select((identity) => identity.signedIn),
  );
  if (!signedIn) return;
  await ref.read(coachTaskProvider.notifier).refresh();
});

class CoachTaskNotifier extends Notifier<CoachTaskState> {
  late final CoachTaskService _service;

  @override
  CoachTaskState build() {
    _service = ref.watch(coachTaskServiceProvider);
    return const CoachTaskState();
  }

  Future<void> refresh({String? clientUserId}) async {
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn || state.busy) return;

    state = state.copyWith(
      operation: CoachTaskOperation.loading,
      clearMessage: true,
      isError: false,
    );

    try {
      final tasks = await _service.listTasks(clientUserId: clientUserId);
      final occurrences = await _service.listOccurrences();

      state = state.copyWith(
        tasks: List.unmodifiable(tasks),
        occurrences: List.unmodifiable(occurrences),
        operation: CoachTaskOperation.idle,
        isError: false,
      );

      await _materializeOwnAssignedTasks(
        tasks: tasks,
        occurrences: occurrences,
        currentUserId: identity.userId,
      );
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
    } catch (_) {
      _fail('No se pudieron cargar las tareas asignadas.');
    }
  }

  Future<bool> assignTask({
    required String clientUserId,
    required String title,
    String category = 'General',
    HabitTaskType type = HabitTaskType.checklist,
    int targetMinutes = 0,
    HabitRecurrenceType recurrence = HabitRecurrenceType.once,
    Set<int> weekdays = const <int>{},
    required DateTime startsOn,
    DateTime? dueAt,
    DateTime? endsOn,
    String instructions = '',
  }) async {
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return false;

    state = state.copyWith(
      operation: CoachTaskOperation.assigning,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.assignTask(
        clientUserId: clientUserId,
        taskPayload: <String, dynamic>{
          'title': title.trim(),
          'category':
              category.trim().isEmpty ? 'General' : category.trim(),
          'task_type': type.name,
          'target_minutes': targetMinutes.clamp(0, 1440).toInt(),
          'recurrence_type': recurrence.name,
          'weekdays': weekdays.toList()..sort(),
          'starts_on': _dateOnly(startsOn),
          'due_at': dueAt?.toUtc().toIso8601String(),
          'ends_on': endsOn == null ? null : _dateOnly(endsOn),
          'coach_instructions': instructions.trim(),
        },
      );
      state = state.copyWith(
        operation: CoachTaskOperation.idle,
        message: 'Tarea asignada.',
        isError: false,
      );
      await refresh(clientUserId: clientUserId);
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo asignar la tarea.');
      return false;
    }
  }

  Future<bool> resolveOccurrence({
    required CoachAssignedTask task,
    required DateTime occurrenceDate,
    required CoachTaskOccurrenceStatus status,
    int minutesSpent = 0,
  }) async {
    if (!task.isClient(ref.read(appIdentityProvider).userId) || state.busy) {
      return false;
    }

    state = state.copyWith(
      operation: CoachTaskOperation.completing,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.setOccurrenceStatus(
        taskId: task.id,
        occurrenceDate: occurrenceDate,
        status: status,
        minutesSpent: minutesSpent.clamp(0, 1440).toInt(),
      );
      state = state.copyWith(
        operation: CoachTaskOperation.idle,
        message: status == CoachTaskOccurrenceStatus.completed
            ? 'Tarea completada.'
            : 'Tarea marcada como omitida.',
        isError: false,
      );
      await refresh();
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo actualizar la tarea.');
      return false;
    }
  }

  Future<bool> addComment({
    required String taskId,
    DateTime? occurrenceDate,
    required String body,
  }) async {
    if (!ref.read(appIdentityProvider).signedIn || state.busy) return false;
    if (body.trim().isEmpty) return false;

    state = state.copyWith(
      operation: CoachTaskOperation.commenting,
      clearMessage: true,
      isError: false,
    );

    try {
      await _service.addComment(
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        body: body,
      );
      final comments = await _service.listComments(taskId);
      final next =
          Map<String, List<CoachTaskComment>>.from(state.commentsByTask)
            ..[taskId] = List.unmodifiable(comments);
      state = state.copyWith(
        commentsByTask: Map.unmodifiable(next),
        operation: CoachTaskOperation.idle,
        message: 'Comentario añadido.',
        isError: false,
      );
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo añadir el comentario.');
      return false;
    }
  }

  Future<List<CoachTaskComment>> loadComments(String taskId) async {
    try {
      final comments = await _service.listComments(taskId);
      final next =
          Map<String, List<CoachTaskComment>>.from(state.commentsByTask)
            ..[taskId] = List.unmodifiable(comments);
      state = state.copyWith(commentsByTask: Map.unmodifiable(next));
      return comments;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return const <CoachTaskComment>[];
    } catch (_) {
      _fail('No se pudieron cargar los comentarios.');
      return const <CoachTaskComment>[];
    }
  }

  Future<CoachTaskAdherence?> loadAdherence(
    String clientUserId, {
    int days = 30,
  }) async {
    if (!ref.read(appIdentityProvider).signedIn) return null;
    try {
      final adherence = await _service.getAdherence(
        clientUserId: clientUserId,
        days: days,
      );
      final next =
          Map<String, CoachTaskAdherence>.from(state.adherenceByClient)
            ..[clientUserId] = adherence;
      state = state.copyWith(adherenceByClient: Map.unmodifiable(next));
      return adherence;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return null;
    } catch (_) {
      _fail('No se pudo calcular la adherencia.');
      return null;
    }
  }

  Future<bool> archiveTask(CoachAssignedTask task) async {
    if (!task.isCoach(ref.read(appIdentityProvider).userId) || state.busy) {
      return false;
    }
    state = state.copyWith(
      operation: CoachTaskOperation.archiving,
      clearMessage: true,
      isError: false,
    );
    try {
      await _service.archiveTask(task.id);
      state = state.copyWith(
        operation: CoachTaskOperation.idle,
        message: 'Tarea archivada.',
        isError: false,
      );
      await refresh(clientUserId: task.clientUserId);
      return true;
    } on PostgrestException catch (error) {
      _fail(_databaseMessage(error));
      return false;
    } catch (_) {
      _fail('No se pudo archivar la tarea.');
      return false;
    }
  }

  void clearClient(String clientUserId) {
    final removedTaskIds = state.tasks
        .where((task) => task.clientUserId == clientUserId)
        .map((task) => task.id)
        .toSet();

    final tasks = state.tasks
        .where((task) => task.clientUserId != clientUserId)
        .toList(growable: false);
    final occurrences = state.occurrences
        .where((item) => !removedTaskIds.contains(item.taskId))
        .toList(growable: false);
    final comments = Map<String, List<CoachTaskComment>>.from(
      state.commentsByTask,
    );
    for (final taskId in removedTaskIds) {
      comments.remove(taskId);
    }
    final adherence =
        Map<String, CoachTaskAdherence>.from(state.adherenceByClient)
          ..remove(clientUserId);

    state = state.copyWith(
      tasks: List.unmodifiable(tasks),
      occurrences: List.unmodifiable(occurrences),
      commentsByTask: Map.unmodifiable(comments),
      adherenceByClient: Map.unmodifiable(adherence),
    );
  }

  List<CoachTaskOccurrence> occurrencesFor(String taskId) {
    return state.occurrences
        .where((item) => item.taskId == taskId)
        .toList(growable: false);
  }

  Future<void> _materializeOwnAssignedTasks({
    required List<CoachAssignedTask> tasks,
    required List<CoachTaskOccurrence> occurrences,
    required String? currentUserId,
  }) async {
    if (currentUserId == null) return;
    final own = tasks
        .where((task) => task.clientUserId == currentUserId)
        .toList(growable: false);
    if (own.isEmpty) return;

    final repository = ref.read(habitTaskRepositoryProvider);
    final localTasks = repository.getTasks(includeArchived: true);

    for (final task in own) {
      HabitTask? existing;
      for (final local in localTasks) {
        if (local.source == HabitTaskSource.coach &&
            local.sourceReference == task.id) {
          existing = local;
          break;
        }
      }

      final localTask = task.toLocalHabitTask(
        reminderEnabled: existing?.reminderEnabled ?? false,
      );
      await repository.saveTask(localTask);

      for (final occurrence
          in occurrences.where((item) => item.taskId == task.id)) {
        await repository.saveCompletion(
          HabitTaskCompletion(
            id: 'coach::${occurrence.id}',
            taskId: localTask.id,
            completedAt: occurrence.completedAt ??
                DateTime(
                  occurrence.occurrenceDate.year,
                  occurrence.occurrenceDate.month,
                  occurrence.occurrenceDate.day,
                  12,
                ),
            minutesSpent: occurrence.minutesSpent,
            status:
                occurrence.status == CoachTaskOccurrenceStatus.completed
                    ? HabitTaskCompletionStatus.completed
                    : HabitTaskCompletionStatus.skipped,
          ),
        );
      }
    }

    ref.read(habitTasksProvider.notifier).refresh();
  }

  void _fail(String message) {
    state = state.copyWith(
      operation: CoachTaskOperation.idle,
      message: message,
      isError: true,
    );
  }

  String _databaseMessage(PostgrestException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('task assignment permission required')) {
      return 'El cliente no concedió permiso para asignar tareas.';
    }
    if (raw.contains('comment permission required')) {
      return 'El cliente no concedió permiso para comentarios.';
    }
    if (raw.contains('already has a final status')) {
      return 'Ese día ya tiene un resultado guardado y no se puede reescribir.';
    }
    if (raw.contains('not due on that date')) {
      return 'La tarea no corresponde a esa fecha.';
    }
    if (raw.contains('permanent authenticated account required')) {
      return 'Se necesita una cuenta permanente.';
    }
    return 'La función de tareas aún no está disponible en el backend activo.';
  }
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
