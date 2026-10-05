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

  static const HabitTaskTemplate personalReading20Minutes = HabitTaskTemplate(
    title: 'Lectura personal',
    category: 'Lectura',
    type: HabitTaskType.readingTimer,
    targetMinutes: 20,
    recurrence: HabitRecurrenceType.daily,
    notes: 'Lee cualquier libro o PDF durante 20 minutos.',
  );

  static const HabitTaskTemplate windDown10Minutes = HabitTaskTemplate(
    title: 'Rutina nocturna',
    category: 'Sueño',
    type: HabitTaskType.reflection,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
    notes: 'Respira, descarga la mente y prepara el entorno para dormir.',
  );

  static const HabitTaskTemplate recoveryPause = HabitTaskTemplate(
    title: 'Pausa de recuperación',
    category: 'Recuperación',
    type: HabitTaskType.reflection,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
    notes: 'Pausa breve para atravesar un impulso sin actuar automáticamente.',
  );

  static const HabitTaskTemplate mobility10Minutes = HabitTaskTemplate(
    title: 'Movilidad 10 min',
    category: 'Movilidad',
    type: HabitTaskType.checklist,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
  );
}
