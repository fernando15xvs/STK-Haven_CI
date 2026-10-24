// Internal Flutter rendering evidence only: v9.21 does not publish animations.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _root='build/cc0_master_surface_v7/v8_authoring/'
  'detail_bake_v915/torso_v916/hand_v917/contact_v918';
const _candidate='$_root/skin_v919/hand_v920';
const _ids=<String>['ex_bench_press','ex_barbell_row','ex_squat'];
const _accents=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

void main() {
  late final Map<String,GlbSkinnedScene> baseline;
  late final Map<String,GlbSkinnedScene> refined;
  setUpAll(() {
    baseline={
      for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
        File('$_root/${id}_v918_contact_mobile_qa.glb')
            .readAsBytesSync(),exerciseId:id),
    };
    refined={
      for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
        File('$_candidate/${id}_v920_hand_surface_mobile_qa.glb')
            .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.21 reproduces three unapproved hand surfaces in both themes',
      () {
    const size=Size(380,380);
    for(final id in _ids) {
      final before=baseline[id]!,after=refined[id]!;
      expect(after.vertexCount,before.vertexCount);
      expect(after.triangleCount,before.triangleCount);
      expect(after.containsRigidEquipment,true);
      expect(after.durationSeconds,closeTo(4,.001));
      for(final dark in [false,true]) {
        for(final accent in _accents) {
          for(final second in [0.0,2.0,4.0]) {
            final f=after.frame(second,size,{
              'STK_REGION_pectoralis_major':accent,
              'STK_REGION_anterior_deltoid':accent,
              'STK_REGION_quadriceps_femoris':accent,
            },dark:dark,poseNormals:true,depthSlices:6);
            expect(f.finite,true);
            expect(f.triangles,greaterThan(0));
            expect(f.parts.any(
              (p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),true);
            expect(f.parts.any(
              (p)=>p.material=='STK_PILOT_STK_CUSHION'),
                id=='ex_bench_press');
          }
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));

  testWidgets('v9.21 captures real Flutter hand geometry with light/dark',
      (tester) async {
    for(final id in _ids) {
      for(final dark in [false,true]) {
        final pose=refined[id]!.frame(2,const Size(380,380),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v921_qa'),
            child:SizedBox(width:380,height:380,child:CustomPaint(
              painter:GlbSkinnedPainter(pose,dark
                ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('v921_qa')));
          final picture=await boundary.toImage(pixelRatio:1);
          final png=await picture.toByteData(format:ui.ImageByteFormat.png);
          expect(png,isNotNull);
          File('build/cc0_master_v7_flutter_qa/v921_${id}_${dark ? "dark" : "light"}.png')
             .writeAsBytesSync(png!.buffer.asUint8List());
          picture.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));
}
