enum AppThemeMode { dark, light, system }

enum AppAccent { blue, violet, emerald, teal, rose, amber, coral, slate }

enum AppCardStyle { elevated, flat }

/// Pure Dart user selections; widget styles and fonts are resolved in Mobile.
enum AppUiStyle { classic, minimalist, compact }
enum AppFontFamily { outfit, inter, manrope, plusJakartaSans }
enum AppTextSize { small, medium, large, custom }

class AppearanceSettings {
  final AppThemeMode mode;
  final AppAccent accent;
  final bool oledBlack;
  final AppCardStyle cardStyle;
  final AppUiStyle uiStyle;
  final AppFontFamily fontFamily;
  final AppTextSize textSize;
  final double customTextScale;
  const AppearanceSettings({
    this.mode = AppThemeMode.dark,
    this.accent = AppAccent.blue,
    this.oledBlack = false,
    this.cardStyle = AppCardStyle.elevated,
    this.uiStyle = AppUiStyle.classic,
    this.fontFamily = AppFontFamily.outfit,
    this.textSize = AppTextSize.medium,
    this.customTextScale = 1.0,
  });
  AppearanceSettings copyWith({
    AppThemeMode? mode,
    AppAccent? accent,
    bool? oledBlack,
    AppCardStyle? cardStyle,
    AppUiStyle? uiStyle,
    AppFontFamily? fontFamily,
    AppTextSize? textSize,
    double? customTextScale,
  }) => AppearanceSettings(
    mode: mode ?? this.mode,
    accent: accent ?? this.accent,
    oledBlack: oledBlack ?? this.oledBlack,
    cardStyle: cardStyle ?? this.cardStyle,
    uiStyle: uiStyle ?? this.uiStyle,
    fontFamily: fontFamily ?? this.fontFamily,
    textSize: textSize ?? this.textSize,
    customTextScale: normalizeCustomScale(customTextScale ?? this.customTextScale),
  );
  double get textScale => switch (textSize) {
    AppTextSize.small => 0.9,
    AppTextSize.medium => 1.0,
    AppTextSize.large => 1.18,
    AppTextSize.custom => normalizeCustomScale(customTextScale),
  };

  static double normalizeCustomScale(double value) =>
      value.isFinite ? value.clamp(0.85, 1.6).toDouble() : 1.0;

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'accent': accent.name,
    'oledBlack': oledBlack,
    'cardStyle': cardStyle.name,
    'uiStyle': uiStyle.name,
    'fontFamily': fontFamily.name,
    'textSize': textSize.name,
    'customTextScale': normalizeCustomScale(customTextScale),
  };
  factory AppearanceSettings.fromJson(Object? raw) {
    if (raw is! Map) return const AppearanceSettings();
    return AppearanceSettings(
      mode: AppThemeMode.values.firstWhere(
        (v) => v.name == raw['mode'],
        orElse: () => AppThemeMode.dark,
      ),
      accent: AppAccent.values.firstWhere(
        (v) => v.name == raw['accent'],
        orElse: () => AppAccent.blue,
      ),
      oledBlack: raw['oledBlack'] == true,
      cardStyle: AppCardStyle.values.firstWhere(
        (v) => v.name == raw['cardStyle'],
        orElse: () => AppCardStyle.elevated,
      ),
      uiStyle: AppUiStyle.values.firstWhere(
        (v) => v.name == raw['uiStyle'],
        orElse: () => AppUiStyle.classic,
      ),
      fontFamily: AppFontFamily.values.firstWhere(
        (v) => v.name == raw['fontFamily'],
        orElse: () => AppFontFamily.outfit,
      ),
      textSize: AppTextSize.values.firstWhere(
        (v) => v.name == raw['textSize'],
        orElse: () => AppTextSize.medium,
      ),
      customTextScale: normalizeCustomScale(
        raw['customTextScale'] is num
            ? (raw['customTextScale'] as num).toDouble()
            : 1.0,
      ),
    );
  }
}
