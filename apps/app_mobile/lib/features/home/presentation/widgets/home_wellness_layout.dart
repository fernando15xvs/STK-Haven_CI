import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Keeps both daily actions visible without forcing unreadable narrow cards.
/// At 320dp or larger accessibility type, the tiles stack vertically.
class HomeWellnessLayout extends StatelessWidget {
  const HomeWellnessLayout({
    super.key,
    required this.hydration,
    required this.steps,
  });

  final Widget hydration;
  final Widget steps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseColumns = constraints.maxWidth >= 355 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        if (!canUseColumns) {
          return Column(
            key: const ValueKey('home_wellness_vertical'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hydration,
              const SizedBox(height: AppSpacing.sm),
              steps,
            ],
          );
        }
        // Only two small tiles are measured. Their natural heights can vary
        // with sensor permissions and quick actions; stretch to the taller one.
        // IntrinsicHeight is deliberately restricted to the horizontal layout.
        return IntrinsicHeight(
          child: Row(
            key: const ValueKey('home_wellness_horizontal'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: hydration),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: steps),
            ],
          ),
        );
      },
    );
  }
}
