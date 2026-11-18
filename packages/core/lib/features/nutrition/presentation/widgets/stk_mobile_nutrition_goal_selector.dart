import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:flutter/material.dart';

/// Compact selector for the mobile nutrition overview.
///
/// The choice is guidance only. Persisting a user-specific preference belongs
/// to the separate profile/intention block; it never creates a calorie plan.
class StkMobileNutritionGoalSelector extends StatelessWidget {
  const StkMobileNutritionGoalSelector({
    super.key,
    required this.audience,
    required this.selected,
    required this.onSelected,
    this.onOpenAdultPlanner,
  });

  final StkNutritionAudience audience;
  final StkNutritionIntent selected;
  final ValueChanged<StkNutritionIntent> onSelected;
  final VoidCallback? onOpenAdultPlanner;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;
    final guidance = StkAgeAwareNutritionPlans.describe(
      audience: audience,
      intent: selected,
    );

    final summary = switch (audience) {
      StkNutritionAudience.under15 =>
        'Orientación no disponible para esta edad.',
      StkNutritionAudience.unknownAge =>
        'Conoce hábitos sin cálculos automáticos.',
      StkNutritionAudience.teen15To17 => switch (selected) {
        StkNutritionIntent.maintenance =>
          'Comidas variadas y energía suficiente para crecer.',
        StkNutritionIntent.volume =>
          'Entrena fuerza, aliméntate bien y recupérate.',
        StkNutritionIntent.deficit =>
          'Hábitos y bienestar, sin dietas restrictivas.',
      },
      StkNutritionAudience.adultDeclared ||
      StkNutritionAudience.adultVerified => switch (selected) {
        StkNutritionIntent.maintenance =>
          'Equilibrio entre alimentación y recuperación.',
        StkNutritionIntent.volume =>
          'Alimentación suficiente para progresar con fuerza.',
        StkNutritionIntent.deficit =>
          'Hábitos sostenibles y ajustes graduales.',
      },
    };

    return Column(
      key: const ValueKey('stk_mobile_nutrition_goal_selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu objetivo', style: typography.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final intent in StkNutritionIntent.values)
              ChoiceChip(
                key: ValueKey('stk_mobile_goal_${intent.name}'),
                label: Text(StkAgeAwareNutritionPlans.label(intent)),
                selected: selected == intent,
                onSelected: (_) => onSelected(intent),
                showCheckmark: true,
                selectedColor: colors.primaryContainer,
              ),
          ],
        ),
        const SizedBox(height: 9),
        Semantics(
          liveRegion: true,
          child: Text(
            summary,
            key: const ValueKey('stk_mobile_goal_summary'),
            style: typography.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (guidance.calorieTargetAllowed &&
            onOpenAdultPlanner != null) ...[
          const SizedBox(height: 5),
          TextButton.icon(
            key: const ValueKey('stk_mobile_open_adult_planner'),
            onPressed: onOpenAdultPlanner,
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: const Text('Revisar mi plan'),
          ),
        ],
      ],
    );
  }
}
