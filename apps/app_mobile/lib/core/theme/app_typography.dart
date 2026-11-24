import 'package:flutter/material.dart';

/// Uniform weight and size tokens; font family comes from ThemeData.
class AppTypography {
  AppTypography._();

  static const _base = TextStyle(
    // Inherit the selected font family from the active Material theme.
    letterSpacing: 0,
    height: 1.3,
  );

  static final displayLarge = _base.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 800)],
    letterSpacing: -1.2,
  );
  static final displayMedium = _base.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: -0.7,
  );
  static final displaySmall = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: -0.4,
  );

  static final headlineLarge = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: -0.2,
  );
  static final headlineMedium = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 600)],
  );
  static final headlineSmall = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 600)],
  );

  static final bodyLarge = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 500)],
  );
  static final bodyMedium = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 500)],
  );
  static final bodySmall = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 500)],
  );

  static final labelLarge = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: 0.8,
  );
  static final labelMedium = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 600)],
    letterSpacing: 0.5,
  );
  static final labelSmall = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 600)],
    letterSpacing: 0.5,
  );

  static final monoLarge = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 700)],
    fontFeatures: [const FontFeature.tabularFigures()],
  );
  static final monoMedium = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    // Flutter 3.38 does not drive variable-font wght via FontWeight.
    fontVariations: const [FontVariation('wght', 600)],
    fontFeatures: [const FontFeature.tabularFigures()],
  );
}
