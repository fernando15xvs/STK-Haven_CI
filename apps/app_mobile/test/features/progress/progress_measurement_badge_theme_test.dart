import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

void main() {
  final record = BodyMeasurement(
    id: 'measure-theme-test',
    date: DateTime(2026, 10, 31),
    chestCm: 101,
    neckCm: 38,
    rightArmCm: 34,
  );

  for (final accent in AppAccent.values) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('silhouette $accent ${brightness.name} 320px OLED text 160%',
          (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final colors = AppColors.from(
          AppearanceSettings(
            accent: accent,
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
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SingleChildScrollView(
                child: BodyMeasurementSilhouette(
                  measurements: [record],
                  selected: MeasurementMetric.chest,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final silhouette = tester.widget<Container>(
          find.byKey(const Key('silhouette_front')));
        final background = silhouette.decoration! as BoxDecoration;
        expect(background.color, colors.surfaceHigh,
          reason: 'Silhouette must use semantic surface for every accent/OLED');
        final heading = tester.widget<Text>(find.text('Medidas corporales'));
        expect(heading.style?.fontFamily, 'Outfit');
        expect(heading.style?.fontSize, AppTypography.headlineSmall.fontSize);
        for (final sample in [
          (
            key: 'measure_chip_chest',
            background: colors.primary,
            titleColor: colors.onPrimary,
            valueColor: colors.onPrimary,
          ),
        ]) {
          final chip = find.byKey(Key(sample.key));
          expect(chip, findsOneWidget);
          final material = tester.widget<Material>(find.descendant(
            of: chip,
            matching: find.byType(Material),
          ).first);
          expect(material.color, sample.background);
          final labels = tester.widgetList<Text>(find.descendant(
            of: chip,
            matching: find.byType(Text),
          )).toList(growable: false);
          expect(labels, hasLength(2));
          expect(labels[0].style!.fontFamily, 'Outfit');
          expect(labels[0].style!.fontSize, AppTypography.labelSmall.fontSize);
          expect(labels[0].style!.color, sample.titleColor);
          expect(labels[1].style!.fontFamily, 'Outfit');
          expect(labels[1].style!.fontSize, AppTypography.bodySmall.fontSize);
          expect(labels[1].style!.color, sample.valueColor);
          expect(labels[1].style!.fontFeatures,
              contains(const FontFeature.tabularFigures()));
          for (final label in labels) {
            expect(
              AppColors.contrast(label.style!.color!, material.color!),
              greaterThanOrEqualTo(4.5),
              reason: '${sample.key} $accent ${brightness.name}',
            );
          }
          final rect = tester.getRect(chip);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
        // Non-selected front labels no longer cover the anatomical figure,
        // but their points must remain visible and accessible.
        expect(find.byKey(const Key('measure_chip_neck')), findsNothing);
        expect(find.byKey(const Key('measure_chip_rightArm')), findsNothing);
        expect(find.byKey(const Key('map_front_neck')), findsOneWidget);
        expect(find.byKey(const Key('map_front_rightArm')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('390px ordinary scale keeps tap and historical detail accessible',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BodyMeasurementSilhouette(
            measurements: [record],
            selected: MeasurementMetric.chest,
            onSelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final target = find.byKey(const Key('map_front_neck'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.byType(MeasurementMuscleDetailPage), findsOneWidget);
    expect(find.text('38.0 cm'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
