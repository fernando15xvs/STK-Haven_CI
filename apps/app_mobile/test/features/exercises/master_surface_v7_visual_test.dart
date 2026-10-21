import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// Experimental mobile-only CC0 anatomy v7. Never exercise catalog media.
const patterns = <String>[
  'overhead_reach_bilateral', 'unilateral_reach_left',
  'unilateral_reach_right', 'bilateral_elbow_curl',
  'hip_hinge', 'squat_articulation', 'split_lunge_left',
];

void main() {
  late final Map<String, GlbSkinnedScene> v6;
  late final Map<String, GlbSkinnedScene> v7;

  setUpAll(() {
    final source=File(
      'build/cc0_master_surface_v6/stk_master_v6_joint_surface_review.glb',
    ).readAsBytesSync();
    final refined=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    expect(refined.length, lessThanOrEqualTo(850 * 1024));
    v6 = {for(final name in patterns)
      name:GlbSkinnedScene.decodeMaster(source,pattern:name)};
    v7 = {for(final name in patterns)
      name:GlbSkinnedScene.decodeMaster(refined,pattern:name)};
    Directory('build/cc0_master_v7_flutter_qa').createSync(recursive:true);
  });

  test('Seven v7 GLB clips remain finite, skinned and cyclic', () {
    for(final name in patterns) {
      final baseline=v6[name]!,scene=v7[name]!;
      expect(scene.vertexCount,baseline.vertexCount);
      expect(scene.triangleCount,baseline.triangleCount);
      expect(scene.durationSeconds, closeTo(4,.001));
      final first=scene.frame(0,const Size(320,320),const {});
      final pose=scene.frame(2,const Size(320,320),const {},
          depthSlices:6,poseNormals:true);
      final loop=scene.frame(4,const Size(320,320),const {});
      expect(first.finite,true);
      expect(pose.finite,true);
      expect(loop.finite,true);
      expect(first.parts.length,loop.parts.length);
      var deviation=0.0;
      for(var part=0;part<first.parts.length;part++) {
        for(var i=0;i<first.parts[part].positions.length;i++) {
          deviation+=(first.parts[part].positions[i]-
                      loop.parts[part].positions[i]).distance;
        }
      }
      expect(deviation,lessThan(.05),reason:name);
      final base=baseline.frame(2,const Size(320,320),const {});
      final detailed=scene.frame(2,const Size(320,320),const {});
      var changed=0.0;
      expect(base.parts.length,detailed.parts.length);
      for(var part=0;part<base.parts.length;part++) {
        final a=base.parts[part].positions,b=detailed.parts[part].positions;
        for(var i=0;i<a.length;i++)changed+=(a[i]-b[i]).distance;
      }
      expect(changed,greaterThan(.5),reason:name);
    }
  });

  testWidgets('Real v7 sculpt creates light and dark review captures',
      (tester) async {
    for(final name in ['overhead_reach_bilateral','squat_articulation',
                       'hip_hinge']) {
      for(final dark in [false,true]) {
        final frame=v7[name]!.frame(2,const Size(320,320),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
          'STK_REGION_latissimus_dorsi':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6);
        await tester.pumpWidget(MaterialApp(
          home:Scaffold(body:Center(
            child:RepaintBoundary(
              key:const Key('v7_mobile_master'),
              child:SizedBox(width:320,height:320,child:CustomPaint(
                painter:GlbSkinnedPainter(frame,dark
                  ?const Color(0xFF12181F):const Color(0xFFF2F5F7)),
              )),
            ),
          )),
        ));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('v7_mobile_master')));
          final image=await boundary.toImage(pixelRatio:1);
          final data=(await image.toByteData(format:ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          expect(data.length,greaterThan(4000));
          File('build/cc0_master_v7_flutter_qa/${name}_'
               '${dark ? "dark" : "light"}.png').writeAsBytesSync(data);
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));
}
