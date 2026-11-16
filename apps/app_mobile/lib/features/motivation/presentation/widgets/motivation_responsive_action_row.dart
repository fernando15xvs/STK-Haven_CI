import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// A two-action row that becomes a vertical layout when text magnification or
/// a narrow viewport would otherwise clip important controls.
class MotivationResponsiveActionRow extends StatelessWidget {
  const MotivationResponsiveActionRow({
    super.key,
    required this.leading,
    required this.action,
    this.compactAction,
  });

  final Widget leading;
  final Widget action;
  /// Optional text-first action for large-text or narrow screens. Omitting an
  /// icon here preserves the full label instead of shrinking accessibility
  /// text or hiding a primary action behind horizontal scrolling.
  final Widget? compactAction;

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
            // Icons and long labels can overflow an internal button Row at
            // 160%-200% text despite tight width constraints. Prefer the
            // caller's full-width text-first alternative in that case.
            SizedBox(width: double.infinity,
              child: compactAction ?? action),
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
