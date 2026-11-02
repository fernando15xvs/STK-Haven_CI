import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _base='build/cc0_master_surface_v7/v8_authoring/detail_bake_v915';
const _new='$_base/torso_v916';
const _ids=['ex_bench_press','ex_barbell_row','ex_squat'];
const _accentColors=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

void main() {
  late GlbSkinnedScene base;
  late GlbSkinnedScene torso;
  late Map<String,GlbSkinnedScene> pilots;
  setUpAll(() {
    base=GlbSkinnedScene.decodeMaster(
      File('$_base/stk_master_v915_mobile_normal_bake_qa.glb')
        .readAsBytesSync(),pattern:'overhead_reach_bilateral');
    torso=GlbSkinnedScene.decodeMaster(
      File('$_new/stk_master_v916_torso_mobile_qa.glb')
        .readAsBytesSync(),pattern:'overhead_reach_bilateral');
    pilots={for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
      File('$_new/${id}_v916_torso_mobile_qa.glb')
        .readAsBytesSync(),exerciseId:id)};
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.16 torso normal bake preserves master animation and mesh',() {
    expect(torso.vertexCount,base.vertexCount);
    expect(torso.triangleCount,base.triangleCount);
    expect(torso.durationSeconds,closeTo(base.durationSeconds,.001));
    for(final t in [0.0,1.1,2.2,3.9]) {
      final before=base.frame(t,const Size(380,380),const {},
        poseNormals:true);
      final after=torso.frame(t,const Size(380,380),const {},
        poseNormals:true);
      expect(before.finite,true);
      expect(after.finite,true);
      expect(before.parts.length,after.parts.length);
      expect(before.triangles,after.triangles);
      final byMaterial={for(final part in before.parts)part.material:part};
      expect(byMaterial.length,before.parts.length);
      for(final part in after.parts) {
        final prior=byMaterial[part.material]!;
        expect(part.positions.length,prior.positions.length);
        for(var i=0;i<part.positions.length;i++) {
          expect((part.positions[i]-prior.positions[i]).distance,
            lessThan(.0005),reason:'Rest and skin topology must be unchanged');
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.16 preserves 55-bone pilot grip/bench objects',() {
    for(final id in _ids) {
      final scene=pilots[id]!;
      expect(scene.id,id);
      expect(scene.containsRigidEquipment,true);
      for(final t in [0.0,1.3,2.1,3.6]) {
        final f=scene.frame(t,const Size(380,380),const {},
          poseNormals:true,depthSlices:6);
        expect(f.finite,true);
        expect(f.parts.any((p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),
          true);
        expect(f.parts.any((p)=>p.material=='STK_PILOT_STK_CUSHION'),
          id=='ex_bench_press');
      }
    }
  },timeout:const Timeout(Duration(minutes:3)));

  test('v9.16 all eight accents are valid in both themes',() {
    for(final dark in [false,true]) {
      for(final color in _accentColors) {
        final f=torso.frame(2,const Size(380,380),{
          'STK_REGION_pectoralis_major':color,
          'STK_REGION_anterior_deltoid':color,
          'STK_REGION_latissimus_dorsi':color,
        },dark:dark,poseNormals:true,depthSlices:6);
        expect(f.finite,true);
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  testWidgets('v9.16 captures real Flutter QA front torso and three pilots',
      (tester) async {
    for(final dark in [true,false]) {
      final options=<String,GlbSkinnedScene>{
        'master_front':torso,
        'bench_press':pilots['ex_bench_press']!,
        'barbell_row':pilots['ex_barbell_row']!,
        'squat':pilots['ex_squat']!,
      };
      for(final item in options.entries) {
        final frame=item.value.frame(1.8,const Size(380,380),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v916'),
            child:SizedBox(width:380,height:380,child:CustomPaint(
              painter:GlbSkinnedPainter(frame,dark
                ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final render=tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('v916')));
          final png=await render.toImage(pixelRatio:1);
          final bytes=await png.toByteData(format:ui.ImageByteFormat.png);
          expect(bytes,isNotNull);
          expect(bytes!.lengthInBytes,greaterThan(4000));
          File('build/cc0_master_v7_flutter_qa/'
             'v916_${item.key}_${dark ? "dark" : "light"}.png')
            .writeAsBytesSync(bytes.buffer.asUint8List());
          png.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));
}
