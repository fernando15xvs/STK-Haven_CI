import 'package:flutter/material.dart';
import '../../domain/models/appearance_settings.dart';

/// Semantic colors resolved from the nearest Theme, never global mutable state.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background, surface, surfaceHigh, surfaceBorder;
  final Color primary, textPrimary, textSecondary, textDisabled;
  final Color success, warning, error, gold, info;
  final bool elevatedCards;
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceBorder,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.error,
    required this.gold,
    required this.info,
    required this.elevatedCards,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      AppColors.from(const AppearanceSettings(), Theme.of(context).brightness);
  static Color accentSeed(AppAccent accent) => Color(switch (accent) {
    AppAccent.blue => 0xFF2962FF,
    AppAccent.violet => 0xFF7C3AED,
    AppAccent.emerald => 0xFF047857,
    AppAccent.teal => 0xFF007C91,
    AppAccent.rose => 0xFFBE185D,
    AppAccent.amber => 0xFF9A6700,
    AppAccent.coral => 0xFFC2410C,
    AppAccent.slate => 0xFF52647C,
  });
  factory AppColors.from(AppearanceSettings settings, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark
        ? (settings.oledBlack ? Colors.black : const Color(0xFF090A0C))
        : const Color(0xFFF4F5F8);
    final surface = dark ? const Color(0xFF111318) : Colors.white;
    final high = dark ? const Color(0xFF1A1D24) : const Color(0xFFEBEEF3);
    // Keep accent text legible on all three surfaces. Controls use onPrimary.
    Color legible(Color color) {
      var hsl = HSLColor.fromColor(color);
      var result = color;
      for (
        var i = 0;
        i < 100 && [bg, surface, high].any((b) => contrast(result, b) < 4.5);
        i++
      ) {
        hsl = hsl.withLightness(
          (hsl.lightness + (dark ? .01 : -.01)).clamp(0, 1),
        );
        result = hsl.toColor();
      }
      return result;
    }

    return AppColors(
      background: bg,
      surface: surface,
      surfaceHigh: high,
      surfaceBorder: dark ? const Color(0xFF343A48) : const Color(0xFFCCD2DD),
      primary: legible(accentSeed(settings.accent)),
      textPrimary: dark ? const Color(0xFFF0F0F3) : const Color(0xFF18202D),
      textSecondary: dark ? const Color(0xFFA4AAB5) : const Color(0xFF535E70),
      textDisabled: dark ? const Color(0xFF777E8B) : const Color(0xFF737C8C),
      success: legible(const Color(0xFF047857)),
      warning: legible(const Color(0xFF9A6700)),
      error: legible(const Color(0xFFCF2547)),
      gold: legible(const Color(0xFF9A6700)),
      info: legible(const Color(0xFF2563EB)),
      elevatedCards: settings.cardStyle == AppCardStyle.elevated,
    );
  }
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
  }

  Color get onPrimary =>
      contrast(primary, Colors.white) >= contrast(primary, Colors.black)
      ? Colors.white
      : Colors.black;
  Color get primaryFaded =>
      Color.alphaBlend(primary.withValues(alpha: .10), surface);
  Color get primarySoft =>
      Color.alphaBlend(primary.withValues(alpha: .18), surface);
  Color get successFaded =>
      Color.alphaBlend(success.withValues(alpha: .10), surface);
  Color get warningFaded =>
      Color.alphaBlend(warning.withValues(alpha: .10), surface);
  Color get border => surfaceBorder;
  List<BoxShadow> get shadows => elevatedCards
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ]
      : const [];

  @override
  AppColors copyWith({Color? primary}) => AppColors(
    background: background,
    surface: surface,
    surfaceHigh: surfaceHigh,
    surfaceBorder: surfaceBorder,
    primary: primary ?? this.primary,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textDisabled: textDisabled,
    success: success,
    warning: warning,
    error: error,
    gold: gold,
    info: info,
    elevatedCards: elevatedCards,
  );
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      surfaceBorder: mix(surfaceBorder, other.surfaceBorder),
      primary: mix(primary, other.primary),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textDisabled: mix(textDisabled, other.textDisabled),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      gold: mix(gold, other.gold),
      info: mix(info, other.info),
      elevatedCards: t < .5 ? elevatedCards : other.elevatedCards,
    );
  }
}
