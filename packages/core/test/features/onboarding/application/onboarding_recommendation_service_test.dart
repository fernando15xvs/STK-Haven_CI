import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/onboarding/application/onboarding_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingRecommendationService', () {
    test('recommends upper/lower for four or five days', () {
      for (final days in [4, 5]) {
        final result = OnboardingRecommendationService.recommend(
          UserExperienceProfile(
            dateOfBirth:DateTime(DateTime.now().year-25,1,1),
            optionalDemographicsConsented:true,
            trainingDaysPerWeek: days,
            trainingGoal: TrainingGoal.hypertrophy,
            trainingExperience: TrainingExperience.intermediate,
            planningPreference: PlanningPreference.recommendation,
          ),
        );
        expect(result?.id, 'prog_upper_lower_4');
      }
    });

    test('recommends full body for a beginner training three days', () {
      final result = OnboardingRecommendationService.recommend(
        UserExperienceProfile(
          dateOfBirth:DateTime(DateTime.now().year-25,1,1),
          optionalDemographicsConsented:true,
          trainingDaysPerWeek: 3,
          trainingGoal: TrainingGoal.strength,
          trainingExperience: TrainingExperience.beginner,
          planningPreference: PlanningPreference.recommendation,
        ),
      );

      expect(result?.id, 'prog_fullbody_3');
    });

    test('a declared minor never receives an adult preset automatically', () {
      final minor=UserExperienceProfile(
        dateOfBirth:DateTime(DateTime.now().year-16,1,1),
        optionalDemographicsConsented:true,
        trainingDaysPerWeek:6,
        trainingGoal:TrainingGoal.hypertrophy,
        trainingExperience:TrainingExperience.advanced,
        planningPreference:PlanningPreference.recommendation,
      );
      expect(OnboardingRecommendationService.recommend(minor),isNull);
    });

    test('consented optional demographics are not required for 15+ eligibility', () {
      final adult = UserExperienceProfile(
        eligibilityBirthDate: DateTime(DateTime.now().year - 25, 1, 1),
        optionalDemographicsConsented: false,
        trainingDaysPerWeek: 4,
        trainingExperience: TrainingExperience.intermediate,
        trainingGoal: TrainingGoal.hypertrophy,
        planningPreference: PlanningPreference.recommendation,
      );
      expect(OnboardingRecommendationService.recommend(adult)?.id,
          'prog_upper_lower_4');
      final teen = adult.copyWith(
        eligibilityBirthDate: DateTime(DateTime.now().year - 16, 1, 1),
      );
      expect(OnboardingRecommendationService.recommend(teen), isNull);
    });

    test('unknown age never automatically receives a high-frequency adult preset', () {
      for(final days in [3,4,5,6]){
        final unknown=UserExperienceProfile(
          trainingDaysPerWeek:days,
          trainingGoal:TrainingGoal.hypertrophy,
          trainingExperience:TrainingExperience.advanced,
          planningPreference:PlanningPreference.recommendation,
        );
        expect(unknown.dateOfBirth,isNull);
        expect(OnboardingRecommendationService.recommend(unknown),isNull);
      }
    });

    test('consent to local demographics does not itself prove adulthood',(){
      const noBirth=UserExperienceProfile(
        optionalDemographicsConsented:true,
        trainingDaysPerWeek:6,
        trainingExperience:TrainingExperience.advanced,
      );
      expect(OnboardingRecommendationService.recommend(noBirth),isNull);
    });

    test('unconsented legacy birth date never auto-selects an adult program',(){
      final legacy=UserExperienceProfile(
        dateOfBirth:DateTime(DateTime.now().year-30,1,1),
        trainingDaysPerWeek:6,
        trainingGoal:TrainingGoal.hypertrophy,
        trainingExperience:TrainingExperience.advanced,
        planningPreference:PlanningPreference.recommendation,
      );
      expect(legacy.optionalDemographicsConsented,isFalse);
      expect(OnboardingRecommendationService.recommend(legacy),isNull);
    });

    test('does not force a program when days are unknown', () {
      final result = OnboardingRecommendationService.recommend(
        const UserExperienceProfile(
          trainingGoal: TrainingGoal.hypertrophy,
          planningPreference: PlanningPreference.recommendation,
        ),
      );

      expect(result, isNull);
    });

    test('self-directed users receive no automatic program', () {
      final result = OnboardingRecommendationService.recommend(
        const UserExperienceProfile(
          trainingDaysPerWeek: 5,
          trainingGoal: TrainingGoal.selfDirected,
          planningPreference: PlanningPreference.selfDirected,
        ),
      );

      expect(result, isNull);
    });
  });
}
