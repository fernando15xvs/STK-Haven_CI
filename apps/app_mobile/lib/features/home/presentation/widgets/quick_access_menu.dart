import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// The backdrop is intentionally independent of accent and text palette:
/// labels are painted over a darkened page in every appearance mode.
class QuickAccessMenu extends StatelessWidget {
  const QuickAccessMenu({super.key, required this.children});
  final List<QuickAccessOption> children;

  static Color scrimFor(Brightness brightness) => Colors.black.withValues(
    alpha: brightness == Brightness.light ? 0.70 : 0.65,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final width = constraints.maxWidth;
      // Preserve three circular actions per row at normal phone widths.
      // Larger accessibility text gets more room instead of a smaller font.
      final columns = scale > 1.85 || width < 220 ? 1
          : scale > 1.3 || width < 282 ? 2 : 3;
      const gap = 12.0;
      final itemWidth = (width - (columns - 1) * gap) / columns;
      return SingleChildScrollView(
        key: const ValueKey('quick_access_scroll'),
        child: SizedBox(
          width: width,
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runAlignment: WrapAlignment.center,
            // A two-line label must not move its circle or first line
            // relative to shorter labels in the same row.
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final option in children)
                SizedBox(width: itemWidth, child: option),
            ],
          ),
        ),
      );
    },
  );
}

class QuickAccessOption extends StatelessWidget {
  const QuickAccessOption({
    super.key, required this.icon, required this.label, required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 13 * 1.3;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: ValueKey('quick_access_icon_$label'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surfaceBorder, width: 2),
                ),
                child: Icon(icon, color: colors.primary, size: 25),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                key: ValueKey('quick_access_label_$label'),
                textAlign: TextAlign.center,
                softWrap: true,
                // Two lines normally; do not clip accessibility-sized labels.
                maxLines: largeText ? null : 2,
                overflow: TextOverflow.visible,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
