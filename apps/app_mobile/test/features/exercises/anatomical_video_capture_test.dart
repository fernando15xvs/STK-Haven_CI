import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// Offline QA only: 3 x 64 frames from the existing animated procedural GLBs.
/// This does NOT render the separately licensed CC0 human (not retargeted).
void main() {
  testWidgets('capture 3 GLB pilots as prerender source frames',
      (tester) async {
    const ids = ['ex_bench_press', 'ex_barbell_row', 'ex_squat'];
    const frames = 64, fps = 16;
    final root = Directory('build/video_comparison/frames');
    root.createSync(recursive: true);
    for (final id in ids) {
      final bytes = File('build/anatomical_3d_glb/' + id + '.glb').readAsBytesSync();
      final scene = GlbSkinnedScene.decode(bytes);
      final destination = Directory(root.path + '/' + id)
        ..createSync(recursive:true);
      for (var i = 0; i < frames; i++) {
        final sampled = scene.frame(i / fps, const Size(320, 320),
          const {
            'STK_PRIMARY': Color(0xFF2962FF),
            'STK_SECONDARY': Color(0xFF779EFF),
          }, dark:true);
        expect(sampled.finite,isTrue);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: RepaintBoundary(
            key: const Key('video_frame'),
            child: SizedBox(width: 320,height:320,
              child:CustomPaint(
                painter:GlbSkinnedPainter(sampled,const Color(0xFF10151B)),
              ),
            ),
          ))),
        ));
        await tester.pump();
        await tester.runAsync(() async {
          final bound = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('video_frame')));
          final picture = await bound.toImage(pixelRatio:1);
          final raw = (await picture.toByteData(format:ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          File(destination.path + '/frame_' + i.toString().padLeft(3,'0') + '.png')
              .writeAsBytesSync(raw);
          picture.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  }, skip: !const bool.fromEnvironment('STK_CAPTURE_VIDEO_PILOTS'),
     timeout: const Timeout(Duration(minutes: 15)));
}
