import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HabitTask', () {
    final monday = DateTime(2026, 9, 7, 9);

    test('round-trips task metadata safely', () {
      final task = HabitTask(
        id: 'bible-10',
        title: 'Leer la Biblia',
        category: 'Fe',
        type: HabitTaskType.readingTimer,
        targetMinutes: 10,
        recurrence: HabitRecurrenceType.weekly,
        weekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
        scheduledAt: monday,
        createdAt: monday,
        updatedAt: monday,
        source: HabitTaskSource.plan,
        visibility: HabitTaskVisibility.private,
        faithSpecific: true,
        reference: 'Juan 1',
        notes: 'Lectura corta',
      );

      final restored = HabitTask.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.type, HabitTaskType.readingTimer);
      expect(restored.targetMinutes, 10);
      expect(restored.weekdays, task.weekdays);
      expect(restored.faithSpecific, isTrue);
      expect(restored.reference, 'Juan 1');
    });

    test('sanitizes invalid durations and weekdays', () {
      final restored = HabitTask.fromJson({
        'id': 'x',
        'title': 'Tarea',
        'targetMinutes': 9000,
        'weekdays': [0, 1, 7, 9],
        'createdAt': monday.toIso8601String(),
      });

      expect(restored.targetMinutes, 1440);
      expect(restored.weekdays, {DateTime.monday, DateTime.sunday});
    });
  });

  group('HabitScheduleService', () {
    final monday = DateTime(2026, 9, 7, 9);

    HabitTask weekly() => HabitTask(
          id: 'mobility',
          title: 'Movilidad',
          recurrence: HabitRecurrenceType.weekly,
          weekdays: const {
            DateTime.monday,
            DateTime.thursday,
          },
          createdAt: monday,
          updatedAt: monday,
        );

    test('weekly recurrence uses local calendar days', () {
      expect(HabitScheduleService.isDueOn(weekly(), monday), isTrue);
      expect(
        HabitScheduleService.isDueOn(
          weekly(),
          monday.add(const Duration(days: 1)),
        ),
        isFalse,
      );
      expect(
        HabitScheduleService.isDueOn(
          weekly(),
          monday.add(const Duration(days: 3)),
        ),
        isTrue,
      );
    });

    test('daily recurrence does not begin before scheduled day', () {
      final task = HabitTask(
        id: 'read',
        title: 'Leer',
        recurrence: HabitRecurrenceType.daily,
        scheduledAt: monday.add(const Duration(days: 2, hours: 4)),
        createdAt: monday,
        updatedAt: monday,
      );

      expect(HabitScheduleService.isDueOn(task, monday), isFalse);
      expect(
        HabitScheduleService.isDueOn(
          task,
          monday.add(const Duration(days: 2)),
        ),
        isTrue,
      );
    });

    test('once task is due only on its target local day', () {
      final task = HabitTask(
        id: 'once',
        title: 'Revisar plan',
        scheduledAt: monday.add(const Duration(days: 1, hours: 8)),
        createdAt: monday,
        updatedAt: monday,
      );

      expect(HabitScheduleService.isDueOn(task, monday), isFalse);
      expect(
        HabitScheduleService.isDueOn(
          task,
          monday.add(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(
        HabitScheduleService.isDueOn(
          task,
          monday.add(const Duration(days: 2)),
        ),
        isFalse,
      );
    });

    test('unfinished current day does not prematurely break prior streak', () {
      final task = HabitTask(
        id: 'daily',
        title: 'Estudio',
        recurrence: HabitRecurrenceType.daily,
        createdAt: monday,
        updatedAt: monday,
      );
      final friday = monday.add(const Duration(days: 4));
      final completions = [
        for (var i = 0; i < 4; i++)
          HabitTaskCompletion(
            id: 'c$i',
            taskId: 'daily',
            completedAt: monday.add(Duration(days: i, hours: 10)),
          ),
      ];

      expect(
        HabitScheduleService.currentStreak(
          task: task,
          completions: completions,
          today: friday,
        ),
        4,
      );
    });

    test('archived tasks are never due', () {
      final task = weekly().copyWith(archived: true);

      expect(HabitScheduleService.isDueOn(task, monday), isFalse);
    });
  });
}
