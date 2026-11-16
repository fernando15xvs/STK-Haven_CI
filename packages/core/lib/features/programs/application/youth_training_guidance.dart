import 'package:core/domain/models/user_experience_profile.dart';

/// Informational guidance. Never modifies a stored training target, creates
/// a program, assigns adult loads, or infers the user's date of birth.
class YouthTrainingGuidance {
  const YouthTrainingGuidance._();

  static String? forProfile(UserExperienceProfile? profile, DateTime now) {
    if(profile==null)return null;
    final age=profile.ageAt(now);
    if(age!=null && age>=18)return null;

    if(age==null){
      return 'Puedes entrenar sin indicar tu edad. '
        'Prioriza ejercicios que controles y descanso suficiente. '
        'No se instalará automáticamente un programa adulto.';
    }

    final experience=profile.trainingExperience;
    final highFrequency=(profile.trainingDaysPerWeek??0)>=5;
    if(experience==TrainingExperience.beginner){
      return highFrequency
        ?'Estás empezando y has seleccionado varios días de entrenamiento. '
          'Prioriza aprender la técnica, alternar esfuerzos y descansar; '
          'consulta a un entrenador cualificado antes de aumentar cargas.'
        :'Empieza con movimientos que puedas controlar, '
          'descanso suficiente y ayuda de un entrenador '
          'cualificado cuando la necesites.';
    }

    return highFrequency
      ?'Has elegido una frecuencia elevada. Reserva tiempo para '
        'recuperarte, aumenta cargas gradualmente según tu experiencia '
        'y consulta con un entrenador cualificado si tienes dudas.'
      :'Prioriza técnica, progresión gradual y recuperación. '
        'Consulta a un entrenador cualificado ante dudas '
        'sobre cargas y supervisión.';
  }
}
