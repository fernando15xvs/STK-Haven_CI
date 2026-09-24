import 'package:core/domain/models/habit_task.dart';

class HabitTaskTemplate {
  final String title;
  final String category;
  final HabitTaskType type;
  final int targetMinutes;
  final HabitRecurrenceType recurrence;
  final Set<int> weekdays;
  final bool faithSpecific;
  final String reference;
  final String notes;

  const HabitTaskTemplate({
    required this.title,
    required this.category,
    required this.type,
    required this.targetMinutes,
    required this.recurrence,
    this.weekdays = const <int>{},
    this.faithSpecific = false,
    this.reference = '',
    this.notes = '',
  });
}

class HabitTaskTemplates {
  const HabitTaskTemplates._();

  static const HabitTaskTemplate bibleReading10Minutes = HabitTaskTemplate(
    title: 'Leer la Biblia',
    category: 'Fe',
    type: HabitTaskType.readingTimer,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
    faithSpecific: true,
    notes: 'Lee durante 10 minutos y guarda una referencia o reflexión si quieres.',
  );

  static const HabitTaskTemplate mobility10Minutes = HabitTaskTemplate(
    title: 'Movilidad 10 min',
    category: 'Movilidad',
    type: HabitTaskType.checklist,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
  );
}
