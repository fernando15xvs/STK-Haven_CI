import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// v9.17 THREE disabled exercise pilots with independent finger IK only.
/// The v9.16 torso master and mobile catalog remain unmodified.
const _folder='build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916';
const _pilotIds=['ex_bench_press','ex_barbell_row','ex_squat'];
const _accents=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),
  Color(0xFFE67722),Color(0xFF7A4DCA),
  Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

void main() {
  late Map<String, GlbSkinnedScene> old;
  late Map<String, GlbSkinnedScene> improved;

  setUpAll(() {
    old={for(final id in _pilotIds) id:
      GlbSkinnedScene.decodeMasterExercise(File(
        '$_folder/${id}_v916_torso_mobile_qa.glb')
        .readAsBytesSync(),exerciseId:id)};
    improved={for(final id in _pilotIds) id:
      GlbSkinnedScene.decodeMasterExercise(File(
        '$_folder/hand_v917/${id}_v917_finger_mobile_qa.glb')
        .readAsBytesSync(),exerciseId:id)};
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.17 30 finger channels are decoded and move visible mesh',() {
    const size=Size(380,380);
    for(final id in _pilotIds) {
      final before=old[id]!,newer=improved[id]!;
      expect(newer.id,id);
      expect(newer.vertexCount,before.vertexCount);
      expect(newer.triangleCount,before.triangleCount);
      expect(newer.durationSeconds,closeTo(4,.001));
      expect(newer.containsRigidEquipment,true);
      var maxChanged=0.0;
      var baselineError=0.0;
      for(final second in [0.0,1.0,2.0,3.0,4.0]) {
        final oldFrame=before.frame(second,size,const {},
          poseNormals:true,depthSlices:1);
        final newFrame=newer.frame(second,size,const {},
          poseNormals:true,depthSlices:1);
        expect(oldFrame.finite,true);
        expect(newFrame.finite,true);
        expect(newFrame.triangles,oldFrame.triangles);
        // Some rigid equipment primitives legitimately share a material.
        // Compare per-material projected shape moments, independent of how
        // the renderer sorts those primitives or duplicates material labels.
        Map<String,List<double>> moments(GlbDrawFrame frame) {
          final sums=<String,List<double>>{};
          for(final part in frame.parts) {
            final values=sums.putIfAbsent(
              part.material,()=>List<double>.filled(4,0));
            for(final point in part.positions) {
              values[0]+=point.dx;
              values[1]+=point.dy;
              values[2]+=point.dx*point.dx;
              values[3]+=point.dy*point.dy;
            }
          }
          return sums;
        }
        final previous=moments(oldFrame);
        final current=moments(newFrame);
        expect(current.keys.toSet(),previous.keys.toSet());
        var changed=0.0;
        for(final material in previous.keys) {
          final a=previous[material]!,b=current[material]!;
          for(var i=0;i<a.length;i++) {
            changed+=(a[i]-b[i]).abs();
          }
        }
        if(second==0) {
          // Runtime animation quaternions are rounded to float32 in glTF.
          // The weighted image-space moments amplify this benign baseline.
          baselineError=changed;
          expect(changed,lessThan(.5),
            reason:'rest-pose float32 roundtrip must be visually stable');
        } else if(second==4) {
          expect((changed-baselineError).abs(),lessThan(.02),
            reason:'four-second loop must return to rest with float32 parity');
        } else if(second==2) {
          maxChanged=changed;
        }
      }
      expect(maxChanged,greaterThan(baselineError+.06),
        reason:'finger movement must exceed the float32 rest-pose noise');
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.17 no interference with rigid bar and bench in eight accents',() {
    for(final id in _pilotIds) {
      final newScene=improved[id]!;
      for(final dark in [false,true]) {
        for(final color in _accents) {
          final result=newScene.frame(1.8,const Size(380,380),{
            'STK_REGION_pectoralis_major':color,
            'STK_REGION_anterior_deltoid':color,
          },dark:dark,poseNormals:true,depthSlices:6);
          expect(result.finite,true);
          expect(result.parts.any(
            (p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),true);
          expect(result.parts.any(
            (p)=>p.material=='STK_PILOT_STK_CUSHION'),
            id=='ex_bench_press');
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  testWidgets('v9.17 exports real light/dark finger poses for three pilots',
      (tester) async {
    for(final id in _pilotIds) {
      for(final dark in [false,true]) {
        final frame=improved[id]!.frame(2,const Size(380,380),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_latissimus_dorsi':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6,zoom:1.20);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v917_hand_grip'),
            child:SizedBox(width:380,height:380,child:CustomPaint(
              painter:GlbSkinnedPainter(frame,dark
                  ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('v917_hand_grip')));
          final png=await boundary.toImage(pixelRatio:1);
          final bytes=await png.toByteData(format:ui.ImageByteFormat.png);
          expect(bytes,isNotNull);
          expect(bytes!.lengthInBytes,greaterThan(4000));
          File('build/cc0_master_v7_flutter_qa/'
               'v917_${id}_${dark ? "dark" : "light"}.png')
            .writeAsBytesSync(bytes.buffer.asUint8List());
          png.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));
}
