import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/features/profile/presentation/pages/appearance_settings_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setAppearance(AppearanceSettings appearance) async {
    state = state.copyWith(appearance: appearance);
  }
}
class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(settingsProvider).appearance;
    return MaterialApp(theme: AppearanceTheme.build(appearance, Brightness.light),
      darkTheme: AppearanceTheme.build(appearance, Brightness.dark),
      themeMode: AppearanceTheme.mode(appearance.mode), themeAnimationDuration: Duration.zero,
      home: const AppearanceSettingsPage());
  }
}
void main() {
  testWidgets('compact phone allows changing mode and all eight accents without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [settingsProvider.overrideWith(_Settings.new)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _App()));
    await tester.ensureVisible(find.text('Claro'));
    await tester.tap(find.text('Claro')); await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appearance.mode, AppThemeMode.light);
    await tester.ensureVisible(find.text('Pizarra'));
    await tester.tap(find.text('Pizarra')); await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appearance.accent, AppAccent.slate);
    expect(find.byType(ChoiceChip), findsNWidgets(11));
    await tester.ensureVisible(find.text('Negro puro OLED'));
    await tester.tap(find.text('Negro puro OLED')); await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appearance.oledBlack, true);
    expect(tester.takeException(), isNull);
  });
}
