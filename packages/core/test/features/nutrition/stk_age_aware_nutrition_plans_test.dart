import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('STK nutrition: correct declared-age boundaries', () {
    test('missing age is not a verified numeric adult', () {
      expect(StkAgeAwareNutritionPlans.audience(
        declaredAge: null, backendVerifiedAdult: true,
      ), StkNutritionAudience.unknownAge);
    });

    test('under 15 is not eligible for nutrition planning', () {
      for (final age in [0, 12, 14]) {
        expect(StkAgeAwareNutritionPlans.audience(
          declaredAge: age, backendVerifiedAdult: true,
        ), StkNutritionAudience.under15);
      }
    });

    test('15–17 always stays educational even if a stale grant exists', () {
      for (final age in [15, 16, 17]) {
        expect(StkAgeAwareNutritionPlans.audience(
          declaredAge: age, backendVerifiedAdult: true,
        ), StkNutritionAudience.teen15To17);
      }
    });

    test('adult declaration is not a remote server authorization', () {
      expect(StkAgeAwareNutritionPlans.audience(
        declaredAge: 18, backendVerifiedAdult: false,
      ), StkNutritionAudience.adultDeclared);
      expect(StkAgeAwareNutritionPlans.audience(
        declaredAge: 29, backendVerifiedAdult: true,
      ), StkNutritionAudience.adultVerified);
    });
  });

  group('All three goals remain accessible as educational choices', () {
    test('no teenager gets automated restriction or adult calculation', () {
      for (final intent in StkNutritionIntent.values) {
        final guidance = StkAgeAwareNutritionPlans.describe(
          audience: StkNutritionAudience.teen15To17,
          intent: intent,
        );
        expect(guidance.title, isNotEmpty);
        expect(guidance.introduction, isNotEmpty);
        expect(guidance.guidance, isNotEmpty);
        expect(guidance.calorieTargetAllowed, isFalse);
        final text = '${guidance.introduction} ${guidance.guidance} '
            '${guidance.disclaimer}'.toLowerCase();
        expect(text, isNot(contains('kcal')));
        expect(text, isNot(contains('gramos/día')));
        expect(text, isNot(contains('come menos')));
      }
      final deficit = StkAgeAwareNutritionPlans.describe(
        audience: StkNutritionAudience.teen15To17,
        intent: StkNutritionIntent.deficit,
      );
      expect(deficit.title, 'Déficit');
      expect(deficit.guidance, contains('sin dietas restrictivas'));
      expect(deficit.guidance, contains('sin'));
    });

    test('unverified adults see three choices without calculated targets', () {
      for (final intent in StkNutritionIntent.values) {
        final g = StkAgeAwareNutritionPlans.describe(
          audience: StkNutritionAudience.adultDeclared,
          intent: intent,
        );
        expect(g.calorieTargetAllowed, isFalse);
        expect(g.disclaimer, contains('autorización'));
      }
    });

    test('verified adult can open separate planner but goal is not saved', () {
      for (final intent in StkNutritionIntent.values) {
        final g = StkAgeAwareNutritionPlans.describe(
          audience: StkNutritionAudience.adultVerified,
          intent: intent,
        );
        expect(g.calorieTargetAllowed, isTrue);
        expect(g.disclaimer, contains('nunca lo guarda automáticamente'));
      }
    });

    test('unknown and under-minimum ages never get numeric guidance', () {
      for (final audience in [
        StkNutritionAudience.unknownAge,
        StkNutritionAudience.under15,
      ]) {
        for (final intent in StkNutritionIntent.values) {
          expect(StkAgeAwareNutritionPlans.describe(
            audience: audience,
            intent: intent,
          ).calorieTargetAllowed, isFalse);
        }
      }
    });
  });
}
