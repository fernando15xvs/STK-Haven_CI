import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// CI-only QA for the unapproved v6 continuity GLB, not the exercise catalog.
const _patterns = <String>[
  'overhead_reach_bilateral',
  'unilateral_reach_left',
  'unilateral_reach_right',
  'bilateral_elbow_curl',
  'hip_hinge',
  'squat_articulation',
  'split_lunge_left',
];

void main() {
  late final Map<String, GlbSkinnedScene> scenes;

  setUpAll(() {
    final bytes = File(
      'build/cc0_master_surface_v6/stk_master_v6_joint_surface_review.glb',
    ).readAsBytesSync();
    expect(bytes.length, lessThanOrEqualTo(850 * 1024));
    scenes = {
      for (final pattern in _patterns)
        pattern: GlbSkinnedScene.decodeMaster(bytes, pattern: pattern),
    };
    Directory('build/cc0_master_v6_flutter_qa').createSync(recursive: true);
  });

  test('V6 retains seven looping, finite, skinned Flutter frames', () {
    for (final scene in scenes.values) {
      expect(scene.vertexCount, greaterThan(1000));
      expect(scene.vertexCount, lessThan(10000));
      expect(scene.triangleCount, lessThan(25000));
      expect(scene.durationSeconds, closeTo(4, .001));
      for (final dark in [true, false]) {
        final initial = scene.frame(
          0, const Size(320, 320), const {}, dark: dark,
        );
        final halfway = scene.frame(
          2, const Size(320, 320),
          {'STK_REGION_pectoralis_major': const Color(0xFF2962FF)},
          dark: dark,
        );
        final loop = scene.frame(
          4, const Size(320, 320), const {}, dark: dark,
        );
        expect(initial.finite, true);
        expect(halfway.finite, true);
        expect(loop.finite, true);
        expect(initial.parts.length, loop.parts.length);
        for (var i = 0; i < initial.parts.length; i++) {
          expect(initial.parts[i].positions.length,
              loop.parts[i].positions.length);
          for (var j = 0; j < initial.parts[i].positions.length; j++) {
            expect((initial.parts[i].positions[j] -
                    loop.parts[i].positions[j]).distance,
                lessThan(.02));
          }
        }
      }
    }
  });

  testWidgets('V6 renders real GLB previews in light and dark themes',
      (tester) async {
    for (final pattern in ['unilateral_reach_left', 'squat_articulation']) {
      for (final dark in [false, true]) {
        final background =
            dark ? const Color(0xFF12181F) : const Color(0xFFF2F5F7);
        final frame = scenes[pattern]!.frame(
          2, const Size(320, 320),
          {'STK_REGION_pectoralis_major': const Color(0xFF2962FF)},
          dark: dark,
        );
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const Key('v6_review_frame'),
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: CustomPaint(
                    painter: GlbSkinnedPainter(frame, background),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        await tester.runAsync(() async {
          final renderObject = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('v6_review_frame')),
          );
          final image = await renderObject.toImage(pixelRatio: 1);
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          expect(png.length, greaterThan(4000));
          File('build/cc0_master_v6_flutter_qa/${pattern}_'
              '${dark ? 'dark' : 'light'}.png').writeAsBytesSync(png);
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
