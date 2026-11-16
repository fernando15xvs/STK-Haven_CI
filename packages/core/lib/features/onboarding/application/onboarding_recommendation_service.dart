import 'package:core/core/constants/preset_programs.dart';
import 'package:core/domain/models/preset_program.dart';
import 'package:core/domain/models/user_experience_profile.dart';

class OnboardingRecommendationService {
  const OnboardingRecommendationService._();

  static PresetProgram? recommend(UserExperienceProfile profile) {
    // A declared minor or a person who chooses not to enter a birth date
    // can still train and build their own routines, but cannot receive an
    // automatically installed adult-oriented preset. Declared adulthood is
    // not backend verification for numeric nutrition.
    final declaredAge=profile.optionalDemographicsConsented
      ?profile.ageAt(DateTime.now()):null;
    if(declaredAge==null || declaredAge<18)return null;
    if (profile.planningPreference == PlanningPreference.selfDirected ||
        profile.trainingGoal == TrainingGoal.selfDirected) {
      return null;
    }

    final days = profile.trainingDaysPerWeek;
    if (days == null) return null;

    if (days <= 2) return _byId('prog_fullbody_2');

    if (days == 3) {
      final beginner =
          profile.trainingExperience == TrainingExperience.beginner;
      final generalFitness =
          profile.trainingGoal == TrainingGoal.activeLifestyle ||
          profile.trainingGoal == TrainingGoal.conditioning;
      return _byId(
        beginner || generalFitness ? 'prog_fullbody_3' : 'prog_ppl_3',
      );
    }

    if (days == 4 || days == 5) {
      return _byId('prog_upper_lower_4');
    }

    if (days >= 6) {
      if (profile.trainingExperience == TrainingExperience.beginner) {
        return _byId('prog_upper_lower_4');
      }
      return _byId('prog_ppl_6');
    }

    return null;
  }

  static PresetProgram _byId(String id) {
    return presetPrograms.firstWhere(
      (program) => program.id == id,
      orElse: () => presetPrograms.first,
    );
  }
}
