import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _patterns=<String>[
  'overhead_reach_bilateral',
  'unilateral_reach_left',
  'unilateral_reach_right',
  'bilateral_elbow_curl',
  'hip_hinge',
  'squat_articulation',
  'split_lunge_left',
];

void main() {
  late final Map<String,GlbSkinnedScene> scenes;
  late final Map<String,dynamic> report;
  setUpAll(() {
    const path='build/cc0_master_mobile_v4/';
    final bytes=File(path+'stk_master_v4_mobile_morph_lod_unapproved.glb')
      .readAsBytesSync();
    report=jsonDecode(File(path+'mobile_master_v4_report.json').readAsStringSync())
      as Map<String,dynamic>;
    expect(report['approved'],false);
    expect(report['enabled'],false);
    expect(report['catalogCount'],229);
    expect(bytes.length,lessThan(850*1024));
    scenes={for(final pattern in _patterns)
      pattern:GlbSkinnedScene.decodeMaster(bytes,pattern:pattern)};
    Directory('build/cc0_master_v4_flutter_qa').createSync(recursive:true);
  });

  test('Seven shared master clips decode, loop and move limbs',() {
    double signature(GlbDrawFrame f)=>f.parts.fold<double>(0,
      (s,p)=>s+p.positions.fold<double>(0,(acc,v)=>acc+v.dx+v.dy));
    for(final pattern in _patterns) {
      final scene=scenes[pattern]!;
      expect(scene.vertexCount,report['vertices']);
      expect(scene.triangleCount,report['triangles']);
      expect(scene.durationSeconds,closeTo(4,.0001));
      expect(scene.id,contains(pattern));
      final start=scene.frame(0,const Size(320,320),const {});
      final middle=scene.frame(2,const Size(320,320),const {});
      final end=scene.frame(4,const Size(320,320),const {});
      expect(start.finite,true);
      expect(middle.finite,true);
      expect((signature(middle)-signature(start)).abs(),greaterThan(1));
      expect(signature(start),closeTo(signature(end),.02));
    }
  });

  test('Morph corrections change the actual projected mesh',() {
    for(final pattern in _patterns) {
      final scene=scenes[pattern]!;
      final driven=scene.frame(2,const Size(320,320),const {});
      final uncorrected=scene.frame(2,const Size(320,320),const {},
        applyMorphs:false);
      expect(driven.parts.length,uncorrected.parts.length);
      var delta=0.0;
      for(var i=0;i<driven.parts.length;i++){
        final a=driven.parts[i].positions,b=uncorrected.parts[i].positions;
        for(var j=0;j<a.length;j++){
          delta+=(a[j]-b[j]).distance;
        }
      }
      expect(delta,greaterThan(.01),reason:pattern);
    }
  });

  test('Color binding for individual muscles supports 8 accents x 2 modes',(){
    final scene=scenes['bilateral_elbow_curl']!;
    const accents=[
      Color(0xFF2962FF),Color(0xFF00A88F),Color(0xFFDA3C78),
      Color(0xFFFEA21A),Color(0xFF8757E8),Color(0xFFDC4242),
      Color(0xFF1870BD),Color(0xFF78931A),
    ];
    for(final dark in [false,true]){
      for(final accent in accents){
        final f=scene.frame(2,const Size(320,320),{
          'STK_REGION_triceps_brachii':accent,
        },dark:dark);
        expect(f.finite,true);
        expect(f.parts.any((p)=>p.material=='STK_REGION_triceps_brachii'),true);
        expect(f.parts.any((p)=>p.material=='STK_BODY'),true);
      }
    }
    final blue=scene.frame(2,const Size(320,320),{
      'STK_REGION_triceps_brachii':const Color(0xFF2962FF)});
    final red=scene.frame(2,const Size(320,320),{
      'STK_REGION_triceps_brachii':const Color(0xFFDC4242)});
    final a=blue.parts.firstWhere((p)=>p.material=='STK_REGION_triceps_brachii');
    final b=red.parts.firstWhere((p)=>p.material=='STK_REGION_triceps_brachii');
    expect(a.colors.first, isNot(b.colors.first));
  });

  testWidgets('All seven master pose patterns rasterize in offline Flutter QA',
      (tester) async {
    for(final pattern in _patterns) {
      final f=scenes[pattern]!.frame(2,const Size(320,320),
        {'STK_REGION_quadriceps_femoris':const Color(0xFF2962FF)});
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
        child:RepaintBoundary(key:const Key('master_frame'),
          child:SizedBox(width:320,height:320,
            child:CustomPaint(painter:GlbSkinnedPainter(
              f,const Color(0xFF111820)))))))));
      await tester.pump();
      await tester.runAsync(()async {
        final boundary=tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('master_frame')));
        final image=await boundary.toImage(pixelRatio:1);
        final png=(await image.toByteData(format:ui.ImageByteFormat.png))!
            .buffer.asUint8List();
        expect(png.length,greaterThan(4000));
        File('build/cc0_master_v4_flutter_qa/'+pattern+'.png')
          .writeAsBytesSync(png);
        image.dispose();
      });
      expect(tester.takeException(),isNull);
    }
  },timeout:const Timeout(Duration(minutes:4)));
}
