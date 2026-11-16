import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/workout_session.dart';

/// Gentle, non-numeric context. An empty workout history is NOT proof that
/// today was a planned rest day. No saved target or workout is changed.
class WellnessRestGuidance {
  const WellnessRestGuidance._();

  static String forToday({
    required UserExperienceProfile? profile,
    required Iterable<WorkoutSession> sessions,
    required DateTime now,
  }) {
    final age=profile?.ageAt(now);
    if(age!=null && age<18){
      return 'Durante el crecimiento, la técnica, la recuperación y '
        'el descanso importan más que perseguir metas de actividad '
        'o contar calorías. Consulta con un profesional si tienes dudas.';
    }

    final plannedDays=profile?.trainingDaysPerWeek;
    if(plannedDays==null){
      return 'Sin una rutina semanal definida, no suponemos cuáles '
        'son tus días de descanso. Tus metas de agua y pasos '
        'son editables, no obligaciones.';
    }
    final finishedToday=sessions.any((session){
      final day=session.finishedAt.toLocal();
      return day.year==now.year && day.month==now.month && day.day==now.day &&
        !session.finishedAt.isAfter(now) &&
        session.durationSeconds>=600 &&
        session.exercises.any((exercise)=>exercise.sets.any(
          (set)=>set.completed && set.setType==WorkoutSetType.working));
    });

    if(finishedToday){
      return 'Hay una sesión completada registrada hoy. '
        'La necesidad de descanso e hidratación depende de tu '
        'actividad y contexto; tus metas no cambian automáticamente.';
    }
    if(plannedDays<7){
      return 'No hay sesión completada registrada hoy; podría ser '
        'un día de descanso, pero no lo asumimos. '
        'No necesitas compensarlo con más pasos ni cambia tu meta.';
    }
    return 'Tu perfil indica entrenamiento todos los días, '
      'pero la recuperación también importa. Puedes revisar '
      'tu planificación y tus metas sin presión.';
  }
}
