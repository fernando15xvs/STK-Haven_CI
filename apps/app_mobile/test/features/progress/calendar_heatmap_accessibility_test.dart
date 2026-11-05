import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/calendar_heatmap_card.dart';

void main() {
  final monday = DateTime(2026, 11, 2);
  final snapshot = CalendarHeatmapSnapshot(
    startDate: monday,
    endDate: DateTime(2026, 11, 8),
    days: List.generate(
      7,
      (index) => CalendarHeatmapDay(
        date: DateTime(2026, 11, 2 + index),
        workoutCount: index == 1 ? 2 : 0,
        isInPeriod: true,
      ),
    ),
    activeDays: 1,
    totalWorkouts: 2,
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'calendar 320px ${brightness.name} / text ${scale.toStringAsFixed(1)} '
        'reads weekdays and original day counts',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final colors = AppColors.from(
              AppearanceSettings(
                accent: AppAccent.violet,
                oledBlack: brightness == Brightness.dark,
              ),
              brightness,
            );
            await tester.pumpWidget(MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                fontFamily: 'Outfit',
                extensions: [colors],
              ),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: CalendarHeatmapCard(
                      snapshot: snapshot,
                      periodLabel: '7D',
                    ),
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();

            for (final spoken in [
              'Lunes', 'Martes', 'Miércoles', 'Jueves',
              'Viernes', 'Sábado', 'Domingo',
            ]) {
              expect(find.bySemanticsLabel(spoken), findsOneWidget);
            }
            expect(
              find.bySemanticsLabel('3 nov 2026 · 2 sesiones'),
              findsOneWidget,
            );
            expect(
              find.bySemanticsLabel('2 nov 2026 · sin sesión'),
              findsOneWidget,
            );
            expect(find.text('DÍAS CON SESIÓN'), findsOneWidget);
            expect(find.text('1'), findsOneWidget);
            expect(find.text('2'), findsOneWidget);
            final firstGlyph = tester.widget<Text>(find.text('L'));
            expect(firstGlyph.style?.fontFamily, 'Outfit');
            expect(firstGlyph.style?.color, colors.textSecondary);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
