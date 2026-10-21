import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/rigged_anatomy_engine.dart';
import '../../../tool/anatomical_3d/rigged_anatomy_preview.dart';

void main() {
  test('rig samples have consistent joints and contacts for all three IDs', () {
    expect(Exercise3d.values.map((e) => e.id), [
      'ex_bench_press', 'ex_barbell_row', 'ex_squat',
    ]);
    for (final ex in Exercise3d.values) {
      final start = Rig3d.sample(ex, 0);
      final end = Rig3d.sample(ex, 1);
      final loaded = Rig3d.sample(ex, .53);
      expect(start.flexion, 0);
      expect(end.flexion, 0);
      expect(loaded.flexion, closeTo(1, .001));
      expect(start.bar.x, 0);
      expect(start.bar.y, end.bar.y);
      for (final side in ['l', 'r']) {
        for (final progress in [0.0, .13, .31, .53, .68, .9, 1.0]) {
          final p = Rig3d.sample(ex, progress);
          expect(p.at('a' + side), start.at('a' + side));
          expect(p.at('t' + side), start.at('t' + side));
          expect(p.at('h' + side).y, closeTo(p.bar.y, .000001));
          expect(p.at('h' + side).z, closeTo(p.bar.z, .000001));
          if (ex == Exercise3d.bench || ex == Exercise3d.row) {
            final a = p.at('s' + side), b = p.at('e' + side),
                c = p.at('h' + side);
            expect((a - b).length,
                closeTo(ex == Exercise3d.bench ? .38 : .40, .00001));
            expect((b - c).length,
                closeTo(ex == Exercise3d.bench ? .35 : .34, .00001));
          } else {
            final a = p.at('u' + side), b = p.at('k' + side),
                c = p.at('a' + side);
            expect((a - b).length, closeTo(.54, .00001));
            expect((b - c).length, closeTo(.50, .00001));
          }
        }
      }
      expect(Body3d.build(ex, loaded).where((x) =>
          x.material == Material3d.primary), isNotEmpty);
      expect(Body3d.build(ex, loaded).where((x) =>
          x.material == Material3d.secondary), isNotEmpty);
    }
  });

  test('3D perspective and color resolution work for all 16 appearances', () {
    for (final ex in Exercise3d.values) {
      for (final mode in Brightness.values) {
        for (final accent in AppAccent.values) {
          final c = AppColors.accentSeed(accent);
          final mesh = Mesh3d.render(ex, Rig3d.sample(ex, .5),
              const Size(360, 360), c, mode == Brightness.dark);
          expect(mesh.triangles, greaterThan(200));
          expect(mesh.triangles, lessThan(8500));
          expect(mesh.positions.length, mesh.triangles * 3);
          expect(mesh.colors.length, mesh.positions.length);
          expect(mesh.depthSpread, greaterThan(.2));
          expect(mesh.positions.every((p) =>
              p.dx.isFinite && p.dy.isFinite), isTrue);
          expect(mesh.colors.toSet().length, greaterThan(12));
          expect(Mesh3d.materialColor(Material3d.primary, c, true), c);
          expect(Mesh3d.materialColor(Material3d.primary, c, false), c);
        }
      }
    }
  });

  for (final exercise in Exercise3d.values) {
    testWidgets('3D rig preview paints ' + exercise.id +
        ' in light and dark Flutter', (tester) async {
      for (final brightness in Brightness.values) {
        for (final accent in [AppAccent.blue, AppAccent.rose]) {
          await tester.pumpWidget(MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: AppearanceTheme.build(
              AppearanceSettings(accent: accent), brightness),
            home: Scaffold(body: Center(child: RiggedAnatomyPreview3d(
              exercise: exercise, progress: .53, dimension: 360,
            ))),
          ));
          await tester.pump();
          expect(find.byKey(const Key('anatomical_3d_canvas')),
              findsOneWidget);
          expect(find.byType(CustomPaint), findsWidgets);
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('anatomical_3d_canvas')));
            final image = await boundary.toImage(pixelRatio: 1);
            expect(image.width, 360);
            expect(image.height, 360);
            final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png))!.buffer.asUint8List();
            expect(bytes.length, greaterThan(6000));
            final output = Directory('build/rigged_anatomy_flutter');
            output.createSync(recursive: true);
            final filename = exercise.id + '-' + brightness.name +
                '-' + accent.name + '.png';
            File(output.path + '/' + filename).writeAsBytesSync(bytes);
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('preview supports reduced motion, pause and scrub',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: RiggedAnatomyPreview3d(exercise: Exercise3d.bench),
    ))));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('anatomical_3d_play_pause')), findsOneWidget);
    await tester.tap(find.byKey(const Key('anatomical_3d_play_pause')));
    await tester.pump();
    expect(find.text('Reproducir'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Center(child: RiggedAnatomyPreview3d(
        exercise: Exercise3d.bench, progress: .5,
      ))),
    )));
    await tester.pump();
    expect(find.byKey(const Key('anatomical_3d_play_pause')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
