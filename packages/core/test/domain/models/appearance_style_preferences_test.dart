import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:test/test.dart';

void main() {
  test('legacy appearance JSON restores without onboarding or settings reset', () {
    final original = SettingsState.fromJson({
      'hasCompletedOnboarding': true,
      'defaultIncrement': 5.0,
      'appearance': {
        'mode': 'light',
        'accent': 'violet',
        'oledBlack': true,
        'cardStyle': 'flat',
      },
    });
    expect(original.hasCompletedOnboarding, isTrue);
    expect(original.defaultIncrement, 5.0);
    expect(original.appearance.mode, AppThemeMode.light);
    expect(original.appearance.accent, AppAccent.violet);
    expect(original.appearance.cardStyle, AppCardStyle.flat);
    expect(original.appearance.uiStyle, AppUiStyle.classic);
    expect(original.appearance.fontFamily, AppFontFamily.outfit);
    expect(original.appearance.textSize, AppTextSize.medium);
    expect(original.appearance.textScale, 1.0);
  });

  test('new preferences round-trip without altering non-visual data', () {
    const initial = SettingsState(
      hasCompletedOnboarding: true,
      weightUnit: WeightUnit.lb,
      appearance: AppearanceSettings(
        mode: AppThemeMode.system,
        accent: AppAccent.emerald,
        uiStyle: AppUiStyle.compact,
        fontFamily: AppFontFamily.plusJakartaSans,
        textSize: AppTextSize.custom,
        customTextScale: 1.45,
      ),
    );
    final decoded = SettingsState.fromJson(initial.toJson());
    expect(decoded.hasCompletedOnboarding, isTrue);
    expect(decoded.weightUnit, WeightUnit.lb);
    expect(decoded.appearance.uiStyle, AppUiStyle.compact);
    expect(decoded.appearance.fontFamily, AppFontFamily.plusJakartaSans);
    expect(decoded.appearance.textSize, AppTextSize.custom);
    expect(decoded.appearance.textScale, closeTo(1.45, 0.00001));
    expect(decoded.appearance.accent, AppAccent.emerald);
    expect(decoded.appearance.mode, AppThemeMode.system);
  });

  test('invalid or extreme scale is safe and all font/UI presets are supported', () {
    expect(AppearanceSettings.fromJson({
      'uiStyle': 'unknown',
      'fontFamily': 'unknown',
      'textSize': 'unknown',
      'customTextScale': -9,
    }).uiStyle, AppUiStyle.classic);
    final low = AppearanceSettings.fromJson({
      'textSize': 'custom', 'customTextScale': -42,
    });
    final high = AppearanceSettings.fromJson({
      'textSize': 'custom', 'customTextScale': 99,
    });
    expect(low.textScale, 0.85);
    expect(high.textScale, 1.6);
    expect(AppearanceSettings.normalizeCustomScale(double.nan), 1);
    expect(const AppearanceSettings(textSize: AppTextSize.small).textScale, 0.9);
    expect(const AppearanceSettings(textSize: AppTextSize.medium).textScale, 1);
    expect(const AppearanceSettings(textSize: AppTextSize.large).textScale, 1.18);
    for (final font in AppFontFamily.values) {
      for (final style in AppUiStyle.values) {
        final settings = AppearanceSettings(fontFamily: font, uiStyle: style);
        final loaded = AppearanceSettings.fromJson(settings.toJson());
        expect(loaded.fontFamily, font);
        expect(loaded.uiStyle, style);
      }
    }
  });
}
