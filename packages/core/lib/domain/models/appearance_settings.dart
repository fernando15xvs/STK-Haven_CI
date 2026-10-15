enum AppThemeMode { dark, light, system }

enum AppAccent { blue, violet, emerald, teal, rose, amber, coral, slate }

enum AppCardStyle { elevated, flat }

class AppearanceSettings {
  final AppThemeMode mode;
  final AppAccent accent;
  final bool oledBlack;
  final AppCardStyle cardStyle;
  const AppearanceSettings({
    this.mode = AppThemeMode.dark,
    this.accent = AppAccent.blue,
    this.oledBlack = false,
    this.cardStyle = AppCardStyle.elevated,
  });
  AppearanceSettings copyWith({
    AppThemeMode? mode,
    AppAccent? accent,
    bool? oledBlack,
    AppCardStyle? cardStyle,
  }) => AppearanceSettings(
    mode: mode ?? this.mode,
    accent: accent ?? this.accent,
    oledBlack: oledBlack ?? this.oledBlack,
    cardStyle: cardStyle ?? this.cardStyle,
  );
  Map<String, Object> toJson() => {
    'mode': mode.name,
    'accent': accent.name,
    'oledBlack': oledBlack,
    'cardStyle': cardStyle.name,
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
    );
  }
}
