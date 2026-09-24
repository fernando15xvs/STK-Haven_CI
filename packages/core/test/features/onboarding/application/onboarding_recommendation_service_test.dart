import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/onboarding/application/onboarding_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingRecommendationService', () {
    test('recommends upper/lower for four or five days', () {
      for (final days in [4, 5]) {
        final result = OnboardingRecommendationService.recommend(
          UserExperienceProfile(
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
        const UserExperienceProfile(
          trainingDaysPerWeek: 3,
          trainingGoal: TrainingGoal.strength,
          trainingExperience: TrainingExperience.beginner,
          planningPreference: PlanningPreference.recommendation,
        ),
      );

      expect(result?.id, 'prog_fullbody_3');
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
