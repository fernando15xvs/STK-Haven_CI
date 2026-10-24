import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import '../../../tool/visual_pilot_preview.dart';

const ids = ['ex_bench_press', 'ex_barbell_row', 'ex_squat'];

void main() {
  final compositions = <String, LottieComposition>{};
  setUpAll(() async {
    for (final id in ids) {
      final bytes = File('build/anatomical_v2/$id.json').readAsBytesSync();
      compositions[id] = await LottieComposition.fromBytes(bytes);
    }
    Directory('build/anatomical_v2_flutter').createSync(recursive: true);
  });

  for (final id in ids) {
    testWidgets('$id 2.5D anatomy highlights target muscles in all 16 themes',
        (tester) async {
      for (final brightness in Brightness.values) {
        for (final accent in AppAccent.values) {
          await tester.pumpWidget(MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: AppearanceTheme.build(
                AppearanceSettings(accent: accent), brightness),
            home: Scaffold(body: Center(
              child: VisualPilotPreview(
                composition: compositions[id]!,
                exerciseName: id,
                // The raised/initial pose keeps the chest/back out of plate occlusion.
                progress: 0,
              ),
            )),
          ));
          await tester.pump();
          await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('pilot_canvas')));
          final image = await boundary.toImage(pixelRatio: 1);
          expect(image.width, 512);
          expect(image.height, 512);
          final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final rgba = data.buffer.asUint8List();
          final color = AppColors.of(
              tester.element(find.byType(VisualPilotPreview))).primary.toARGB32();
          var matches = 0;
          for (var i = 0; i < rgba.length; i += 4) {
            if (rgba[i] == ((color >> 16) & 255) &&
                rgba[i + 1] == ((color >> 8) & 255) &&
                rgba[i + 2] == (color & 255)) {
              matches++;
            }
          }
          expect(matches, greaterThan(50),
              reason: 'Target muscles must use the active STK theme accent');
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          File('build/anatomical_v2_flutter/' + id + '-' +
              brightness.name + '-' + accent.name + '.png')
              .writeAsBytesSync(png.buffer.asUint8List());
          image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
