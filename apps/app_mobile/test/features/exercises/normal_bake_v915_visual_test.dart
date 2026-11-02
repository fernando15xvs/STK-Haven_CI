import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _source='build/cc0_master_surface_v7/v8_authoring';
const _output='$_source/detail_bake_v915';
const _exercises=['ex_bench_press','ex_barbell_row','ex_squat'];

void main() {
  late final GlbSkinnedScene original, baked;
  late final Map<String,GlbSkinnedScene> pilots;

  setUpAll(() {
    original=GlbSkinnedScene.decodeMaster(
        File('$_source/stk_master_v8_anatomy_preview.glb')
          .readAsBytesSync(),pattern:'squat_articulation');
    baked=GlbSkinnedScene.decodeMaster(
        File('$_output/stk_master_v915_mobile_normal_bake_qa.glb')
          .readAsBytesSync(),pattern:'squat_articulation');
    pilots={
      for(final id in _exercises) id:
        GlbSkinnedScene.decodeMasterExercise(
          File('$_output/${id}_v915_mobile_normal_bake_qa.glb')
            .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.15 mobile bake keeps the exact previous animated geometry',() {
    expect(baked.vertexCount,original.vertexCount);
    expect(baked.triangleCount,original.triangleCount);
    expect(baked.durationSeconds,closeTo(original.durationSeconds,.001));
    for(final second in [0.0,1.0,2.0,3.8]) {
      final old=original.frame(second,const Size(350,350),const {},
        poseNormals:true);
      final refined=baked.frame(second,const Size(350,350),const {},
        poseNormals:true);
      expect(refined.finite,true);
      expect(refined.triangles,old.triangles);
      expect(refined.parts.length,old.parts.length);
      final oldParts={for(final p in old.parts)p.material:p};
      expect(oldParts.length,old.parts.length);
      for(final part in refined.parts) {
        final previous=oldParts[part.material]!;
        expect(previous.positions.length,part.positions.length);
        for(var i=0;i<part.positions.length;i++) {
          expect((part.positions[i]-previous.positions[i]).distance,
                 lessThan(.002));
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.15 three baked pilots retain their rigid equipment',() {
    for(final id in _exercises) {
      final scene=pilots[id]!;
      expect(scene.containsRigidEquipment,true);
      for(final second in [0.0,1.5,3.5]) {
        final frame=scene.frame(second,const Size(350,350),const {},
          poseNormals:true,depthSlices:5);
        expect(frame.finite,true);
        expect(frame.parts.any((p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),
          true);
        expect(frame.parts.any((p)=>p.material=='STK_PILOT_STK_CUSHION'),
          id=='ex_bench_press');
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.15 high-poly GLBs cannot be used in mobile preview',() {
    final high=File('$_output/stk_master_v915_high_detail_authoring.glb')
      .readAsBytesSync();
    expect(high.length,greaterThan(850*1024));
    expect(()=>GlbSkinnedScene.decodeMaster(high,
      pattern:'squat_articulation'),throwsFormatException);
    for(final ex in _exercises) {
      final exercise=File('$_output/${ex}_v915_high_detail_authoring.glb')
        .readAsBytesSync();
      expect(exercise.length,greaterThan(1400*1024));
      expect(()=>GlbSkinnedScene.decodeMasterExercise(exercise,
        exerciseId:ex),throwsFormatException);
    }
  });

  testWidgets('v9.15 captures both themes using baked 55-bone shading',
      (tester) async {
    for(final dark in [false,true]) {
      for(final id in ['squat_articulation','bench_sample']) {
        final scene=id=='bench_sample'?pilots['ex_bench_press']!:baked;
        final frame=scene.frame(2,const Size(350,350),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v915_surface'),
            child:SizedBox(width:350,height:350,child:CustomPaint(
              painter:GlbSkinnedPainter(frame,dark
                ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
             find.byKey(const Key('v915_surface')));
          final image=await boundary.toImage(pixelRatio:1);
          final data=await image.toByteData(format:ui.ImageByteFormat.png);
          expect(data,isNotNull);
          File('build/cc0_master_v7_flutter_qa/'
            'v915_${id}_${dark ? "dark" : "light"}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));
}
