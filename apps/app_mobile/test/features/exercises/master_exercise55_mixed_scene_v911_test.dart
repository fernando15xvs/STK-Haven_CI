import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/anatomical_glb_preview.dart';

const pilots=['ex_bench_press','ex_barbell_row','ex_squat'];
const folder='build/cc0_master_surface_v7/three_exercise_pilots_v99/scapular_v910';

void main() {
  final scenes=<String,GlbSkinnedScene>{};
  setUpAll(() {
    for(final id in pilots) {
      final path='$folder/${id}_master55_v910_scapular_qa.glb';
      scenes[id]=GlbSkinnedScene.decodeMasterExercise(
        File(path).readAsBytesSync(),exerciseId:id);
    }
  });

  test('v9.11 all three 55-joint clips contain visible rigid equipment',() {
    for(final id in pilots) {
      final scene=scenes[id]!;
      expect(scene.id,id);
      expect(scene.containsRigidEquipment,true);
      expect(scene.triangleCount,greaterThan(4000));
      expect(scene.durationSeconds,closeTo(4,.001));
      for(final second in [0.0,1.3,2.2,3.8]) {
        final frame=scene.frame(second,const Size(320,320),const {},
          depthSlices:3,poseNormals:second==0);
        final parts=frame.parts.where(
          (item)=>item.material.startsWith('STK_PILOT_')).toList();
        expect(parts,isNotEmpty);
        expect(parts.any((item)=>
          item.material=='STK_PILOT_STK_EQUIPMENT'),true);
        expect(parts.any((item)=>
          item.material=='STK_PILOT_STK_CUSHION'),
          id=='ex_bench_press');
        for(final item in parts) {
          expect(item.depth.isFinite,true);
          expect(item.positions.every((p)=>p.dx.isFinite&&p.dy.isFinite),
            true);
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));

  test('v9.11 rejects unsupported or mismatched exercise IDs',() {
    final bytes=File(
      '$folder/ex_bench_press_master55_v910_scapular_qa.glb',
    ).readAsBytesSync();
    expect(()=>GlbSkinnedScene.decodeMasterExercise(
      bytes,exerciseId:'ex_unknown'),throwsFormatException);
    expect(()=>GlbSkinnedScene.decodeMasterExercise(
      bytes,exerciseId:'ex_squat'),throwsFormatException);
  });

  testWidgets('v9.11 equipment scenes do not use body-only GPU', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:AnatomicalGlbPreview(
        scene:scenes['ex_bench_press']!,dimension:260,progress:.5,
        experimentalIndexedGpu:true,experimentalGpuMorphs:true,
        experimentalGpuSkinning:true,experimentalNativeGpuStatic:true),
    )));
    expect(find.byKey(const Key('skinned_glb_canvas')),findsOneWidget);
    expect(find.byWidgetPredicate((w)=>
      w is CustomPaint && w.painter is GlbSkinnedPainter),findsOneWidget);
    expect(find.byType(AndroidView),findsNothing);
    expect(find.byType(UiKitView),findsNothing);
  });
}
