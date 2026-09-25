import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachAssignedTask', () {
    final created = DateTime(2026, 9, 24, 9);
    final starts = DateTime(2026, 9, 24);

    test('maps cloud assignment into coach-sourced HabitTask', () {
      final task = CoachAssignedTask(
        id: 'cloud-task-1',
        relationshipId: 'rel-1',
        coachUserId: 'coach-1',
        clientUserId: 'client-1',
        title: 'Movilidad',
        category: 'Recovery',
        type: HabitTaskType.checklist,
        targetMinutes: 10,
        recurrence: HabitRecurrenceType.daily,
        weekdays: const <int>{},
        startsOn: starts,
        dueAt: DateTime(2026, 9, 24, 18),
        coachInstructions: 'Suave',
        status: CoachAssignedTaskStatus.active,
        createdAt: created,
        updatedAt: created,
      );

      final local = task.toLocalHabitTask(reminderEnabled: true);

      expect(local.id, 'coach::cloud-task-1');
      expect(local.source, HabitTaskSource.coach);
      expect(local.visibility, HabitTaskVisibility.shareable);
      expect(local.sourceReference, 'cloud-task-1');
      expect(local.reminderEnabled, isTrue);
      expect(local.notes, 'Suave');
      expect(local.archived, isFalse);
    });

    test('archived cloud task becomes archived local mirror', () {
      final task = CoachAssignedTask(
        id: 'cloud-task-2',
        relationshipId: 'rel-1',
        coachUserId: 'coach-1',
        clientUserId: 'client-1',
        title: 'Walk',
        category: 'General',
        type: HabitTaskType.checklist,
        targetMinutes: 20,
        recurrence: HabitRecurrenceType.once,
        weekdays: const <int>{},
        startsOn: starts,
        coachInstructions: '',
        status: CoachAssignedTaskStatus.archived,
        createdAt: created,
        updatedAt: created,
      );

      expect(task.toLocalHabitTask().archived, isTrue);
    });

    test('parser tolerates unknown task values conservatively', () {
      final task = CoachAssignedTask.fromJson({
        'id': 'x',
        'relationship_id': 'r',
        'coach_user_id': 'c',
        'client_user_id': 'u',
        'title': 'Task',
        'category': 'General',
        'task_type': 'unknown',
        'target_minutes': 9999,
        'recurrence_type': 'unknown',
        'weekdays': [0, 1, 8],
        'starts_on': '2026-09-24',
        'status': 'unknown',
        'created_at': '2026-09-24T09:00:00Z',
        'updated_at': '2026-09-24T09:00:00Z',
      });

      expect(task.type, HabitTaskType.checklist);
      expect(task.recurrence, HabitRecurrenceType.once);
      expect(task.targetMinutes, 1440);
      expect(task.weekdays, {1});
      expect(task.status, CoachAssignedTaskStatus.archived);
    });
  });

  group('HabitTask skipped outcomes', () {
    final task = HabitTask(
      id: 'daily',
      title: 'Daily task',
      recurrence: HabitRecurrenceType.daily,
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
    );
    final day = DateTime(2026, 9, 24, 12);

    test('skipped occurrence resolves today without counting completed', () {
      final completion = HabitTaskCompletion(
        id: 'skip-1',
        taskId: task.id,
        completedAt: day,
        status: HabitTaskCompletionStatus.skipped,
      );

      expect(
        HabitScheduleService.isResolvedOn(task, [completion], day),
        isTrue,
      );
      expect(
        HabitScheduleService.isCompletedOn(task, [completion], day),
        isFalse,
      );
    });

    test('skipped occurrence breaks completion streak', () {
      final completions = [
        HabitTaskCompletion(
          id: 'c1',
          taskId: task.id,
          completedAt: DateTime(2026, 9, 22, 12),
        ),
        HabitTaskCompletion(
          id: 'c2',
          taskId: task.id,
          completedAt: DateTime(2026, 9, 23, 12),
          status: HabitTaskCompletionStatus.skipped,
        ),
      ];

      expect(
        HabitScheduleService.currentStreak(
          task: task,
          completions: completions,
          today: DateTime(2026, 9, 24, 9),
        ),
        0,
      );
    });
  });
}
