import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

/// QA-only. Capture actual 53-joint CC0 LOD, NEVER the old procedural rig.
/// One four-second cycle per exercise at 16 frames/s for MP4 comparison.
void main() {
  testWidgets('capture licensed CC0 humanoid for H264 comparison',(tester)async{
    const ids=['ex_bench_press','ex_barbell_row','ex_squat'];
    const fps=16,frames=64;
    final root=Directory('build/cc0_video_comparison/frames')
      ..createSync(recursive:true);
    for(final exercise in ids){
      final bytes=File('build/cc0_53bone_retarget/'+exercise+
        '_mobile_lod.glb').readAsBytesSync();
      final scene=GlbSkinnedScene.decode(bytes);
      final out=Directory(root.path+'/'+exercise)
        ..createSync(recursive:true);
      for(var i=0;i<frames;i++){
        final pose=scene.frame(i/fps,const Size(320,320),const {
          'STK_PRIMARY':Color(0xFF2962FF),
          'STK_SECONDARY':Color(0xFF779EFF),
        },dark:true);
        expect(pose.finite,isTrue);
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
          child:RepaintBoundary(key:const Key('cc0_frame'),
            child:SizedBox(width:320,height:320,
              child:CustomPaint(painter:GlbSkinnedPainter(
                pose,const Color(0xFF10151B))))),
        ))));
        await tester.pump();
        await tester.runAsync(()async{
          final boundary=tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('cc0_frame')));
          final image=await boundary.toImage(pixelRatio:1);
          final png=(await image.toByteData(format:ui.ImageByteFormat.png))!
            .buffer.asUint8List();
          File(out.path+'/frame_'+i.toString().padLeft(3,'0')+'.png')
            .writeAsBytesSync(png);
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    }
  },skip:!const bool.fromEnvironment('STK_CAPTURE_CC0_VIDEO'),
    timeout:const Timeout(Duration(minutes:15)));
}
