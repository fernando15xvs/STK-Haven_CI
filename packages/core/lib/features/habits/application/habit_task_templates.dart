import 'package:core/domain/models/habit_task.dart';

class HabitTaskTemplate {
  final String title;
  final String key;
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
    this.key = '',
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
    key: 'bible',
    title: 'Leer la Biblia',
    category: 'Fe',
    type: HabitTaskType.readingTimer,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
    faithSpecific: true,
    notes: 'Lee durante 10 minutos y guarda una referencia o reflexión si quieres.',
  );

  static const HabitTaskTemplate personalReading20Minutes = HabitTaskTemplate(
    key: 'reading',
    title: 'Lectura personal',
    category: 'Lectura',
    type: HabitTaskType.readingTimer,
    targetMinutes: 20,
    recurrence: HabitRecurrenceType.daily,
    notes: 'Lee cualquier libro o PDF durante 20 minutos.',
  );

  static const HabitTaskTemplate windDown10Minutes = HabitTaskTemplate(
    key: 'wind_down',
    title: 'Rutina nocturna',
    category: 'Sueño',
    type: HabitTaskType.reflection,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
    notes: 'Respira, descarga la mente y prepara el entorno para dormir.',
  );

  static const HabitTaskTemplate breathingPause = HabitTaskTemplate(
    key:'breathing', title:'Respiración guiada',category:'Enfoque',type:HabitTaskType.reflection,
    targetMinutes:5,recurrence:HabitRecurrenceType.once,notes:'Pausa de respiración opcional.');

  static const HabitTaskTemplate recoveryPause = HabitTaskTemplate(
    key: 'personal_pause',
    title: 'Pausa de recuperación',
    category: 'Recuperación',
    type: HabitTaskType.reflection,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.once,
    notes: 'Pausa breve para atravesar un impulso sin actuar automáticamente.',
  );

  static const HabitTaskTemplate mobility10Minutes = HabitTaskTemplate(
    key: 'mobility',
    title: 'Movilidad 10 min',
    category: 'Movilidad',
    type: HabitTaskType.checklist,
    targetMinutes: 10,
    recurrence: HabitRecurrenceType.daily,
  );
}
