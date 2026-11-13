import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/presentation/widgets/routine_weekday_selector.dart';

void main() {
  testWidgets('weekday schedule stays legible in light, dark and OLED with all accents',
      (tester) async {
    for (final accent in AppAccent.values) {
      for (final variant in <(Brightness, bool)>[
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final settings = AppearanceSettings(
          accent: accent,
          oledBlack: variant.$2,
          mode: variant.$1 == Brightness.light
              ? AppThemeMode.light
              : AppThemeMode.dark,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppearanceTheme.build(settings, variant.$1),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 288,
                  child: RoutineWeekdaySelector(
                    selectedDays: const {1, 3, 5},
                    onDayTapped: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(RoutineWeekdaySelector), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '${accent.name}, ${variant.$1}, oled=${variant.$2}');
      }
    }
  });
}
