import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:flutter/material.dart';

/// Inclusive goal navigation. A selection is informational until an adult
/// with a fresh server grant explicitly calculates and saves a separate plan.
class StkAgeAwareNutritionGoals extends StatelessWidget {
  const StkAgeAwareNutritionGoals({
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
    return Card(
      key: const ValueKey('stk_nutrition_goals_15_plus'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.track_changes_outlined,
                    color: colors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Tu enfoque nutricional',
                    style: typography.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontVariations: const [FontVariation('wght', 800)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              audience.isAdolescent
                  ? 'Los tres objetivos están disponibles como orientación '
                      'adaptada a tu crecimiento, sin dietas automáticas.'
                  : 'Explora mantenimiento, volumen o déficit. '
                      'Elegir una opción no genera un plan por sí solo.',
              style: typography.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final intent in StkNutritionIntent.values)
                  ChoiceChip(
                    key: ValueKey('stk_goal_${intent.name}'),
                    label: Text(StkAgeAwareNutritionPlans.label(intent)),
                    selected: intent == selected,
                    onSelected: (_) => onSelected(intent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('stk_nutrition_guidance'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guidance.introduction,
                      style: typography.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(guidance.guidance,
                        style: typography.bodyMedium),
                    const SizedBox(height: 8),
                    Text(guidance.disclaimer,
                        style: typography.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
            if (guidance.calorieTargetAllowed &&
                onOpenAdultPlanner != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('stk_goal_open_adult_planner'),
                  onPressed: onOpenAdultPlanner,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Revisar cálculo adulto opcional'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
