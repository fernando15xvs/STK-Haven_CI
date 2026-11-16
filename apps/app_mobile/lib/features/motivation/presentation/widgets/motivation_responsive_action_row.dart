import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// A two-action row that becomes a vertical layout when text magnification or
/// a narrow viewport would otherwise clip important controls.
class MotivationResponsiveActionRow extends StatelessWidget {
  const MotivationResponsiveActionRow({
    super.key,
    required this.leading,
    required this.action,
  });

  final Widget leading;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
      final compact = constraints.maxWidth < 360 || largeText;
      if (compact) {
        return Column(
          key: const ValueKey('motivation_action_row_stacked'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(height: AppSpacing.sm),
            // Icon+label buttons need a tight, finite width here. An Align
            // passes loose constraints, allowing their intrinsic Row to grow
            // wider than the 320dp viewport under accessibility text scaling.
            SizedBox(width: double.infinity, child: action),
          ],
        );
      }
      return Row(
        key: const ValueKey('motivation_action_row_inline'),
        children: [
          Expanded(child: leading),
          const SizedBox(width: AppSpacing.sm),
          action,
        ],
      );
    });
  }
}
