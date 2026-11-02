import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// 55-joint v8 sculpt, derived from 229-exercise STK internal QA; never
/// a catalog asset or an anatomist-reviewed human body.
const _folder='build/cc0_master_surface_v7/v8_authoring';
const _pilots=['ex_bench_press','ex_barbell_row','ex_squat'];
const _patterns=['overhead_reach_bilateral','bilateral_elbow_curl',
  'hip_hinge','squat_articulation','split_lunge_left'];
const _accents=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];

void main() {
  late final Map<String,GlbSkinnedScene> v7;
  late final Map<String,GlbSkinnedScene> v8;
  late final Map<String,GlbSkinnedScene> exercise;
  setUpAll(() {
    final old=File('build/cc0_master_surface_v7/'
      'stk_master_v7_surface_preview.glb').readAsBytesSync();
    final raw=File('$_folder/stk_master_v8_anatomy_preview.glb')
      .readAsBytesSync();
    expect(raw.length,lessThanOrEqualTo(850*1024));
    v7={for(final p in _patterns)
      p:GlbSkinnedScene.decodeMaster(old,pattern:p)};
    v8={for(final p in _patterns)
      p:GlbSkinnedScene.decodeMaster(raw,pattern:p)};
    exercise={for(final id in _pilots) id:
      GlbSkinnedScene.decodeMasterExercise(
        File('$_folder/${id}_master55_v8_sculpt_qa.glb').readAsBytesSync(),
        exerciseId:id)};
    Directory('build/cc0_master_v7_flutter_qa')
      .createSync(recursive:true);
  });

  test('v9.13 sculpt changes the visible surface without changing clips', () {
    const size=Size(380,380);
    for(final pattern in _patterns) {
      final original=v7[pattern]!,art=v8[pattern]!;
      expect(art.vertexCount,original.vertexCount);
      expect(art.triangleCount,original.triangleCount);
      expect(art.durationSeconds,closeTo(original.durationSeconds,.001));
      for(final second in [0.0,1.0,2.0,3.9]) {
        // Depth-sliced triangles can move between layers when geometry
        // improves. Compare unsliced anatomical parts by stable material
        // name, not transient painter/depth ordering.
        final a=original.frame(second,size,const {},depthSlices:1);
        final b=art.frame(second,size,const {},depthSlices:1);
        expect(b.finite,true);
        expect(b.triangles,a.triangles);
        expect(b.parts.length,a.parts.length);
        final sources={for(final part in a.parts) part.material:part};
        expect(sources.length,a.parts.length);
        var deviation=0.0;
        for(final refined in b.parts) {
          final before=sources[refined.material];
          expect(before,isNotNull);
          expect(before!.positions.length,refined.positions.length);
          for(var i=0;i<before.positions.length;i++) {
            deviation+=(before.positions[i]-
                        refined.positions[i]).distance;
          }
        }
        expect(deviation,greaterThan(.2),reason:'$pattern $second');
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.13 three improved exercise pilots retain bar and bench', () {
    for(final id in _pilots) {
      final scene=exercise[id]!;
      expect(scene.id,id);
      expect(scene.containsRigidEquipment,true);
      for(final second in [0.0,1.4,2.0,3.6]) {
        final frame=scene.frame(second,const Size(380,380),
          const {},poseNormals:second==0,depthSlices:6);
        expect(frame.finite,true);
        final parts=frame.parts.where(
          (p)=>p.material.startsWith('STK_PILOT_')).toList();
        expect(parts,isNotEmpty);
        expect(parts.any((p)=>p.material=='STK_PILOT_STK_CUSHION'),
               id=='ex_bench_press');
        expect(parts.any((p)=>p.material=='STK_PILOT_STK_EQUIPMENT'),true);
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  testWidgets('v9.13 exports close-up light/dark anatomical comparisons',
      (tester) async {
    // Use existing CI artifact folder. 8 accent options are checked in both
    // themes; export one selected accent per theme, not 16 large screenshots.
    for(final dark in [false,true]) {
      for(final accent in _accents) {
        final color=accent;
        final swatches=<String,Color>{
          'STK_REGION_pectoralis_major':color,
          'STK_REGION_anterior_deltoid':color,
          'STK_REGION_posterior_deltoid':color,
          'STK_REGION_latissimus_dorsi':color,
          'STK_REGION_quadriceps_femoris':color,
          'STK_REGION_gluteus_maximus':color,
        };
        final scene=v8['squat_articulation']!;
        final frame=scene.frame(2,const Size(380,380),swatches,
           dark:dark,poseNormals:true,depthSlices:6,zoom:.82);
        expect(frame.finite,true);
      }
      for(final id in ['overhead_reach_bilateral','squat_articulation']) {
        final frame=v8[id]!.frame(2,const Size(380,380),{
          'STK_REGION_pectoralis_major':const Color(0xFF2962FF),
          'STK_REGION_anterior_deltoid':const Color(0xFF2962FF),
          'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF),
        },dark:dark,poseNormals:true,depthSlices:6,zoom:.82);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('v913_master'),
            child:SizedBox(width:380,height:380,child:CustomPaint(
              painter:GlbSkinnedPainter(frame,dark
                ?const Color(0xFF111722):const Color(0xFFF2F5F8)),
            )),
          ),
        ))));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
             find.byKey(const Key('v913_master')));
          final image=await boundary.toImage(pixelRatio:1);
          final data=await image.toByteData(format:ui.ImageByteFormat.png);
          expect(data,isNotNull);
          File('build/cc0_master_v7_flutter_qa/'
               'v913_${id}_${dark ? "dark" : "light"}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },timeout:const Timeout(Duration(minutes:5)));
}
