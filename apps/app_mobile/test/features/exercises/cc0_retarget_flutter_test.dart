import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_preview.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/anatomical_glb_staging.dart';

const ids=['ex_bench_press','ex_barbell_row','ex_squat'];
void main() {
  final scenes=<String,GlbSkinnedScene>{};
  setUpAll(() {
    Directory('build/cc0_flutter_review').createSync(recursive:true);
    final manifest=jsonDecode(File(
      'build/cc0_53bone_retarget/manifest.json').readAsStringSync());
    expect(manifest['approved'],false);
    expect(manifest['enabled'],false);
    expect(manifest['catalogCount'],229);
    for(final id in ids) {
      final raw=File('build/cc0_53bone_retarget/' + id + '_mobile_lod.glb')
          .readAsBytesSync();
      final staged=AnatomicalGlbStaging.parse(raw);
      expect(staged.id,id);
      expect(staged.jointCount,53);
      expect(staged.meshCount,id=='ex_bench_press' ? 3 : 2);
      expect(staged.animationCount,1);
      expect(staged.materialRoles,containsAll(['body','primary','secondary']));
      expect(raw.length,lessThan(850*1024));
      scenes[id]=AnatomicalGlbPreview.decode(raw);
    }
  });
  test('53-bone GLB playback changes its skinned geometry and loops',(){
    for(final id in ids){
      final scene=scenes[id]!;
      expect(scene.vertexCount,greaterThan(3000));
      expect(scene.vertexCount,lessThan(30000));
      expect(scene.triangleCount,greaterThan(8000));
      expect(scene.triangleCount,lessThan(25000));
      final a=scene.frame(0,const Size(320,320),const {});
      final b=scene.frame(2,const Size(320,320),const {});
      final loop=scene.frame(4,const Size(320,320),const {});
      expect(a.finite,isTrue);
      expect(b.finite,isTrue);
      expect(a.parts.length,greaterThanOrEqualTo(4));
      double signature(GlbDrawFrame f)=>f.parts.fold(0,
        (s,p)=>s+p.positions.fold(0,(a,v)=>a+v.dx+v.dy));
      expect((signature(a)-signature(b)).abs(),greaterThan(2));
      expect(signature(a),closeTo(signature(loop),.5));
    }
  });
  for(final id in ids){
    testWidgets('CC0 53-bone LOD paints $id',(tester)async {
      for(final brightness in Brightness.values){
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration:Duration.zero,
          theme:AppearanceTheme.build(const AppearanceSettings(),brightness),
          home:Scaffold(body:Center(child:AnatomicalGlbPreview(
            scene:scenes[id]!,progress:.5,dimension:320))),
        ));
        await tester.pump();
        final widget=find.byKey(const Key('skinned_glb_canvas'));
        expect(widget,findsOneWidget);
        await tester.runAsync(()async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(widget);
          final image=await boundary.toImage(pixelRatio:1);
          final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          expect(bytes.length,greaterThan(5000));
          File('build/cc0_flutter_review/' + id + '_' +
               brightness.name + '.png').writeAsBytesSync(bytes);
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    });
  }
  testWidgets('CC0 respects reduced motion',(tester)async{
    await tester.pumpWidget(MaterialApp(home:MediaQuery(
      data:const MediaQueryData(disableAnimations:true),
      child:Scaffold(body:Center(child:AnatomicalGlbPreview(
        scene:scenes['ex_squat']!,progress:.5))),
    )));
    await tester.pump();
    expect(find.byKey(const Key('skinned_glb_play_pause')),findsNothing);
  });
}
