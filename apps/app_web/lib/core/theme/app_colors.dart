import 'package:flutter/material.dart';

export 'package:core/domain/models/settings_state.dart';

// ─── Colors ─────────────────────────────────────────────────────────────────
// Primary palette — OLED-first dark theme
// Rule: #2962FF only on CTAs, active states, and primary metrics
class AppColors {
  AppColors._();

  static const background    = Color(0xFF090A0C); // OLED black
  static const surface       = Color(0xFF111318); // elevated surface
  static const surfaceHigh   = Color(0xFF1A1D24); // modals, sheets
  static const surfaceBorder = Color(0xFF222632); // explicit border color

  // Accent — use sparingly
  static const primary       = Color(0xFF2962FF); // CTAs and active states only
  static const primaryFaded  = Color(0x1A2962FF); // tinted backgrounds (10% alpha)
  static const primarySoft   = Color(0xFF13234E); // richer accent surface

  // Semantic
  static const success       = Color(0xFF00C853);
  static const successFaded  = Color(0x1A00C853);
  static const warning       = Color(0xFFFFAB00);
  static const warningFaded  = Color(0x1AFFAB00);
  static const error         = Color(0xFFFF1744);
  static const gold          = Color(0xFFFFD740); // PR / trophy highlight
  static const info          = Color(0xFF43A5FF);

  // Text hierarchy
  static const textPrimary   = Color(0xFFF0F0F3);
  static const textSecondary = Color(0xFF8C9099);
  static const textDisabled  = Color(0xFF4A4D56);

  static Color get border => surfaceBorder;
}

class AppTypography {
  AppTypography._();

  static const _base = TextStyle(
    fontFamily: 'Outfit',
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static final displayLarge  = _base.copyWith(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1.2);
  static final displayMedium = _base.copyWith(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.7);
  static final displaySmall  = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4);

  static final headlineLarge  = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  static final headlineMedium = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final headlineSmall  = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  static final bodyLarge  = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400);
  static final bodyMedium = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400);
  static final bodySmall  = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  static final labelLarge  = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8);
  static final labelMedium = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static final labelSmall  = _base.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary);

  static final monoLarge  = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: [const FontFeature.tabularFigures()]);
  static final monoMedium = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [const FontFeature.tabularFigures()]);
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets pagePadding  = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding  = EdgeInsets.all(md);
  static const EdgeInsets sectionGap   = EdgeInsets.only(bottom: xl);
}

class AppRadius {
  AppRadius._();

  static const double xs  = 6;
  static const double sm  = 10;
  static const double md  = 14;
  static const double lg  = 20;
  static const double xl  = 28;
  static const double full = 999;

  static final xs_  = BorderRadius.circular(xs);
  static final sm_  = BorderRadius.circular(sm);
  static final md_  = BorderRadius.circular(md);
  static final lg_  = BorderRadius.circular(lg);
  static final xl_  = BorderRadius.circular(xl);
}

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

class AppElevation {
  AppElevation._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get low => soft;

  static List<BoxShadow> get accent => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.18),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ];
}

class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
}
