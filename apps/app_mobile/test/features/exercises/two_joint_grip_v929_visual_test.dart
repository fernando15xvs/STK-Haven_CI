// STK Haven v9.29 2-joint skin-contact experimental Flutter visual QA.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _root='build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916/hand_v917/contact_v918/'
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925/two_joint_v929';
const _exerciseIds=['ex_bench_press','ex_barbell_row','ex_squat'];
const _accents=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

void main() {
  late final Map<String,GlbSkinnedScene> scenes;
  setUpAll(() {
    scenes={
      for(final id in _exerciseIds)
        id:GlbSkinnedScene.decodeMasterExercise(
            File('$_root/'+id+'_v929_two_joint_grip_mobile_qa.glb')
                .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa')
        .createSync(recursive:true);
  });

  test('v9.29 two-joint QA keeps finite 3D skin for 8 accents and 2 modes',() {
    const resolution=Size(360,360);
    for(final id in _exerciseIds) {
      final scene=scenes[id]!;
      expect(scene.vertexCount,greaterThan(4727));
      expect(scene.triangleCount,greaterThan(9843));
      expect(scene.triangleCount,lessThanOrEqualTo(20000));
      expect(scene.containsRigidEquipment,true);
      expect(scene.durationSeconds,closeTo(4,.001));
      for(final dark in [false,true]) {
        for(final accent in _accents) {
          for(final t in [0.0,1.0,2.0,3.0,4.0]) {
            final frame=scene.frame(t,resolution,{
              'STK_REGION_pectoralis_major':accent,
              'STK_REGION_anterior_deltoid':accent,
              'STK_REGION_quadriceps_femoris':accent,
            },dark:dark,poseNormals:true,depthSlices:6);
            expect(frame.finite,true);
            expect(frame.parts.any(
                (p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),true);
          }
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));

  testWidgets('v9.29 six genuine Flutter review PNG frames', (tester) async {
    for(final id in _exerciseIds) {
      for(final dark in [false,true]) {
        const size=Size(360,360);
        final frame=scenes[id]!.frame(2.0,size,{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v929_preview'),
            child:SizedBox(width:360,height:360,child:CustomPaint(
              painter:GlbSkinnedPainter(frame,dark
                  ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('v929_preview')));
          final image=await boundary.toImage(pixelRatio:1);
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          expect(bytes,isNotNull);
          File('build/cc0_master_v7_flutter_qa/v929_'+id+'_'
              +(dark?'dark':'light')+'.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));
}
