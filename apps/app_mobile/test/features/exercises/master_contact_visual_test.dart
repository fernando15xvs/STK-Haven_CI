import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _patterns=[
  'overhead_reach_bilateral','unilateral_reach_left',
  'unilateral_reach_right','bilateral_elbow_curl',
  'hip_hinge','squat_articulation','split_lunge_left',
];

void main() {
  late final Map<String,GlbSkinnedScene> scenes;
  setUpAll(() {
    final data=File('build/cc0_master_contacts_v5/stk_master_v5_contact_review.glb')
      .readAsBytesSync();
    expect(data.length,lessThan(850*1024));
    scenes={for(final name in _patterns)
      name:GlbSkinnedScene.decodeMaster(data,pattern:name)};
    Directory('build/cc0_master_v5_flutter_qa').createSync(recursive:true);
  });

  test('Seven contact constrained scenes are finite, move, and loop',() {
    double signature(GlbDrawFrame frame)=>frame.parts.fold<double>(0,
        (sum,part)=>sum+part.positions.fold<double>(0,
          (s,point)=>s+point.dx+point.dy));
    for(final name in _patterns){
      final scene=scenes[name]!;
      expect(scene.vertexCount,greaterThan(3000));
      expect(scene.vertexCount,lessThan(10000));
      expect(scene.triangleCount,lessThan(25000));
      expect(scene.durationSeconds,closeTo(4,.001));
      final initial=scene.frame(0,const Size(320,320),const {});
      final peak=scene.frame(2,const Size(320,320),const {});
      final loop=scene.frame(4,const Size(320,320),const {});
      expect(initial.finite,true);
      expect(peak.finite,true);
      expect((signature(peak)-signature(initial)).abs(),greaterThan(1));
      expect(signature(initial),closeTo(signature(loop),.02));
    }
  });

  testWidgets('Render seven updated CC0 v5 poses in light and dark',
      (tester) async {
    for(final name in _patterns) {
      for(final dark in [true,false]){
        final frame=scenes[name]!.frame(2,const Size(320,320),{
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_latissimus_dorsi':const Color(0xFF2962FF),
        },dark:dark);
        final background=dark
            ?const Color(0xFF12181F):const Color(0xFFF2F5F7);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('contact_preview'),
             child:SizedBox(width:320,height:320,
                child:CustomPaint(painter:GlbSkinnedPainter(
                  frame,background)))))));
        await tester.pump();
        await tester.runAsync(() async {
          final bound=tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('contact_preview')));
          final image=await bound.toImage(pixelRatio:1);
          final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          expect(bytes.length,greaterThan(4000));
          File('build/cc0_master_v5_flutter_qa/$name' +
              (dark?'_dark.png':'_light.png')).writeAsBytesSync(bytes);
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));
}
