// STK Haven v9.43: QA-only 18 side-by-side real GLB torso comparisons.
// Left is v9.41, right is v9.42. Never published as an exercise asset.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _root='build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916/hand_v917/contact_v918/'
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925/'
    'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932/'
    'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937/'
    'left_thumb_angle_v938/cuticles_v939/lower_leg_v940/torso_v941';
const _ids=['ex_bench_press','ex_barbell_row','ex_squat'];
const _accent=Color(0xFF2962FF);
const _themes=<String,Color>{
  'STK_REGION_pectoralis_major':_accent,
  'STK_REGION_anterior_deltoid':_accent,
  'STK_REGION_latissimus_dorsi':_accent,
};

void main() {
  late final Map<String,GlbSkinnedScene> before;
  late final Map<String,GlbSkinnedScene> after;

  setUpAll(() {
    before={
      for (final id in _ids)
        id:GlbSkinnedScene.decodeMasterExercise(
          File('$_root/${id}_v941_torso_volume_mobile_qa.glb')
              .readAsBytesSync(),exerciseId:id),
    };
    after={
      for (final id in _ids)
        id:GlbSkinnedScene.decodeMasterExercise(
          File('$_root/upper_v942/${id}_v942_upper_torso_mobile_qa.glb')
              .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa')
        .createSync(recursive:true);
  });

  testWidgets('v9.43 18 compare renders: three poses, pilots and modes',
      (tester) async {
    for(final id in _ids) {
      expect(before[id]!.containsRigidEquipment,true);
      expect(after[id]!.containsRigidEquipment,true);
      expect(before[id]!.triangleCount,after[id]!.triangleCount);
      for(final dark in [false,true]) {
        final background=dark
            ?const Color(0xFF111722):const Color(0xFFF2F5F8);
        for(final second in [0,2,4]) {
          const size=Size(360,360);
          final f0=before[id]!.frame(second.toDouble(),size,_themes,
              dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
          final f1=after[id]!.frame(second.toDouble(),size,_themes,
              dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
          expect(f0.finite,true);
          expect(f1.finite,true);
          await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
            child:RepaintBoundary(key:const Key('v943_compare'),
              child:SizedBox(width:720,height:360,child:Row(children:[
                SizedBox(width:360,height:360,child:CustomPaint(
                  painter:GlbSkinnedPainter(f0,background))),
                SizedBox(width:360,height:360,child:CustomPaint(
                  painter:GlbSkinnedPainter(f1,background))),
              ])),
            ),
          ))));
          await tester.pump();
          await tester.runAsync(() async {
            final boundary=tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('v943_compare')));
            final image=await boundary.toImage(pixelRatio:1);
            final pixels=await image.toByteData(format:ui.ImageByteFormat.png);
            expect(pixels,isNotNull);
            File('build/cc0_master_v7_flutter_qa/v943_compare_${id}_'
                '${dark?'dark':'light'}_t${second}.png')
                .writeAsBytesSync(pixels!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(),isNull);
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));
}
