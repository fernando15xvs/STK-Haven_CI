import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_volume_headline.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets('total volume readable at ${width.toInt()}px ${brightness.name}, text 1.6',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final colors = AppColors.from(
          const AppearanceSettings(),
          brightness,
        );
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [colors]),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ProgressVolumeHeadline(
                  volumeKg: 149801,
                  weightUnit: WeightUnit.kg,
                  trailing: const Text('+22,8%'),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('149.801'), findsOneWidget);
        expect(find.text('KG'), findsOneWidget);
        expect(find.text('+22,8%'), findsOneWidget);
        final rect =
            tester.getRect(find.byKey(const ValueKey('progress_total_volume_value')));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('lb value uses same Spanish separators as graph tooltip',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProgressVolumeHeadline(
          volumeKg: 1000,
          weightUnit: WeightUnit.lb,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('LB'), findsOneWidget);
    expect(find.textContaining('.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long totals with trailing badge do not overflow at 320 px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ProgressVolumeHeadline(
            volumeKg: 123456789,
            weightUnit: WeightUnit.kg,
            trailing: Text('-12,4%'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('123.456.789'), findsOneWidget);
    expect(find.text('-12,4%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
