export 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_radius.dart';
export 'app_ui_styles.dart';

// ─── Colors ─────────────────────────────────────────────────────────────────
// Primary palette — OLED-first dark theme
// Rule: #2962FF only on CTAs, active states, and primary metrics
// ─── Motion ──────────────────────────────────────────────────────────────────
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

// ─── Elevation ───────────────────────────────────────────────────────────────
class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft(BuildContext context) =>
      AppColors.of(context).shadows;

  static List<BoxShadow> accent(BuildContext context) =>
      !AppColors.of(context).elevatedCards
      ? []
      : [
          BoxShadow(
            color: AppColors.of(context).primary.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ];
}

// ─── Responsive tokens ──────────────────────────────────────────────────────
class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
}
