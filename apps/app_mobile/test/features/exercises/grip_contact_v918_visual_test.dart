import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _v917='build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916/hand_v917';
const _v918='$_v917/contact_v918';
const _exercises=['ex_bench_press','ex_barbell_row','ex_squat'];
const _accents=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

Map<String,List<double>> _projectedMoments(GlbDrawFrame frame) {
  final sum=<String,List<double>>{};
  for(final part in frame.parts) {
    final m=sum.putIfAbsent(part.material,()=>
      List<double>.filled(3,0));
    for(final p in part.positions) {
      m[0]+=p.dx;
      m[1]+=p.dy;
      m[2]+=p.dx*p.dx+p.dy*p.dy;
    }
  }
  return sum;
}

double _momentDifference(GlbDrawFrame a,GlbDrawFrame b) {
  final first=_projectedMoments(a),second=_projectedMoments(b);
  expect(first.keys.toSet(),second.keys.toSet());
  var total=0.0;
  for(final name in first.keys) {
    final left=first[name]!,right=second[name]!;
    for(var i=0;i<left.length;i++) {
      total+=(left[i]-right[i]).abs();
    }
  }
  return total;
}

void main() {
  late final Map<String,GlbSkinnedScene> original,calibrated;

  setUpAll(() {
    original={
      for(final id in _exercises) id:GlbSkinnedScene.decodeMasterExercise(
        File('$_v917/${id}_v917_finger_mobile_qa.glb')
          .readAsBytesSync(),exerciseId:id)
    };
    calibrated={
      for(final id in _exercises) id:GlbSkinnedScene.decodeMasterExercise(
        File('$_v918/${id}_v918_contact_mobile_qa.glb')
          .readAsBytesSync(),exerciseId:id)
    };
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.18 renders safe hand rotation while retaining 55-bone exercise',
      () {
    const size=Size(380,380);
    for(final id in _exercises) {
      final prior=original[id]!,newer=calibrated[id]!;
      expect(newer.vertexCount,prior.vertexCount);
      expect(newer.triangleCount,prior.triangleCount);
      expect(newer.durationSeconds,closeTo(4,.001));
      expect(newer.containsRigidEquipment,true);
      final a=prior.frame(2,size,const {},poseNormals:true,depthSlices:1);
      final b=newer.frame(2,size,const {},poseNormals:true,depthSlices:1);
      expect(a.finite,true);
      expect(b.finite,true);
      expect(b.triangles,a.triangles);
      expect(_momentDifference(a,b),greaterThan(.02),
        reason:'wrist changes must be visible, not metadata only');
      final seamA=newer.frame(0,size,const {},
        poseNormals:true,depthSlices:1);
      final seamB=newer.frame(4,size,const {},
        poseNormals:true,depthSlices:1);
      expect(seamA.finite,true);
      expect(seamB.finite,true);
      expect(_momentDifference(seamA,seamB),lessThan(.15),
        reason:'calibrated grip must remain loop safe');
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.18 still renders original rigid equipment in 8 accents and themes',
      () {
    for(final id in _exercises) {
      final scene=calibrated[id]!;
      for(final dark in [false,true]) {
        for(final accent in _accents) {
          final frame=scene.frame(1.8,const Size(380,380),{
            'STK_REGION_pectoralis_major':accent,
            'STK_REGION_anterior_deltoid':accent,
          },dark:dark,poseNormals:true,depthSlices:6);
          expect(frame.finite,true);
          expect(frame.parts.any((p)=>
              p.material=='STK_PILOT_STK_EQUIPMENT'),true);
          expect(frame.parts.any((p)=>
              p.material=='STK_PILOT_STK_CUSHION'),
              id=='ex_bench_press');
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));

  testWidgets('v9.18 captures left-right hand/grip QA light and dark',
      (tester) async {
    for(final id in _exercises) {
      for(final dark in [false,true]) {
        final scene=calibrated[id]!;
        final pose=scene.frame(2,const Size(380,380),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v918'),
            child:SizedBox(width:380,height:380,child:CustomPaint(
              painter:GlbSkinnedPainter(pose,dark
                  ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('v918')));
          final image=await boundary.toImage(pixelRatio:1);
          final data=await image.toByteData(format:ui.ImageByteFormat.png);
          expect(data,isNotNull);
          File('build/cc0_master_v7_flutter_qa/'
              'v918_${id}_${dark ? "dark" : "light"}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));
}
