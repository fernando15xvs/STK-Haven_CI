import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_preview.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/anatomical_glb_staging.dart';

const ids=['ex_bench_press','ex_barbell_row','ex_squat'];
void main(){
  final scenes=<String,GlbSkinnedScene>{};
  final metrics=<String,Object>{};
  setUpAll((){
    Directory('build/anatomical_glb_flutter').createSync(recursive:true);
    for(final id in ids){
      final bytes=File('build/anatomical_3d_glb/$id.glb').readAsBytesSync();
      final clock=Stopwatch()..start();
      final scene=AnatomicalGlbPreview.decode(bytes);
      clock.stop();
      scenes[id]=scene;
      metrics[id]={
        'bytes':bytes.length,'vertexCount':scene.vertexCount,
        'triangleCount':scene.triangleCount,
        'decodeMicros':clock.elapsedMicroseconds,
        'context':'Flutter test host; not iPhone/Android performance'
      };
    }
  });
  tearDownAll((){
    File('build/anatomical_glb_flutter/metrics.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(metrics));
  });
  test('GLB joint animation moves the skinned vertices and loops',(){
    for(final id in ids){
      final scene=scenes[id]!;
      expect(scene.id,id);
      expect(scene.bytes,lessThan(850*1024));
      expect(scene.vertexCount,greaterThan(5000));
      expect(scene.triangleCount,greaterThan(10000));
      expect(scene.durationSeconds,closeTo(4,.0001));
      final a=scene.frame(0,const Size(360,360),const {},dark:true);
      final b=scene.frame(2,const Size(360,360),const {},dark:true);
      final end=scene.frame(4,const Size(360,360),const {},dark:true);
      expect(a.finite,isTrue);
      expect(b.finite,isTrue);
      expect(a.triangles,scene.triangleCount);
      expect(a.parts.length,greaterThan(25));
      double signature(GlbDrawFrame f)=>f.parts.fold(0.0,(sum,p)=>
        sum+p.positions.fold(0.0,(s,o)=>s+o.dx*.1+o.dy*.3));
      expect((signature(a)-signature(b)).abs(),greaterThan(1),
        reason:'GLB joint animation must move visible geometry');
      expect(signature(a),closeTo(signature(end),.1));
    }
  });
  test('16 combinations preserve active muscle materials',(){
    for(final id in ids){
      for(final brightness in Brightness.values){
        for(final accent in AppAccent.values){
          final c=AppColors.accentSeed(accent);
          final frame=scenes[id]!.frame(1.2,const Size(320,320),
             {'STK_PRIMARY':c},dark:brightness==Brightness.dark);
          expect(frame.finite,isTrue);
          expect(frame.parts.where((p)=>p.material=='STK_PRIMARY'),
              isNotEmpty);
          expect(frame.parts.every((p)=>p.indices.length%3==0),isTrue);
          expect(frame.parts.every((p)=>p.colors.length==p.positions.length),
              isTrue);
        }
      }
    }
  });
  for(final id in ids){
    testWidgets('GLB painted in Flutter: $id', (tester)async{
      for(final brightness in Brightness.values){
        await tester.pumpWidget(MaterialApp(
          themeAnimationDuration:Duration.zero,
          theme:AppearanceTheme.build(const AppearanceSettings(),brightness),
          home:Scaffold(body:Center(child:AnatomicalGlbPreview(
            scene:scenes[id]!,progress:.52,dimension:320))),
        ));
        await tester.pump();
        expect(find.byKey(const Key('skinned_glb_canvas')),findsOneWidget);
        await tester.runAsync(()async{
          final boundary=tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('skinned_glb_canvas')));
          final image=await boundary.toImage(pixelRatio:1);
          expect(image.width,320);expect(image.height,320);
          final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!
              .buffer.asUint8List();
          expect(bytes.length,greaterThan(4000));
          File('build/anatomical_glb_flutter/'+id+'-'+brightness.name+'.png')
              .writeAsBytesSync(bytes);
          image.dispose();
        });
        expect(tester.takeException(),isNull);
      }
    });
  }
  testWidgets('Reduced motion respects chosen frame',(tester)async{
    await tester.pumpWidget(MaterialApp(home:MediaQuery(
      data:const MediaQueryData(disableAnimations:true),
      child:Scaffold(body:Center(child:AnatomicalGlbPreview(
        scene:scenes['ex_squat']!,progress:.5))),
    )));
    await tester.pump();
    expect(find.byKey(const Key('skinned_glb_play_pause')),findsNothing);
    expect(tester.takeException(),isNull);
  });
  test('Prototypes remain excluded from the shipped catalogue',(){
    final pubspec=File('pubspec.yaml').readAsStringSync();
    expect(pubspec,isNot(contains('build/anatomical_3d_glb')));
    expect(pubspec,isNot(contains('anatomical_glb_flutter')));
    final manifest=jsonDecode(
      File('build/anatomical_3d_glb/manifest.json').readAsStringSync());
    expect(manifest['approved'],false);
    expect(manifest['enabled'],false);
    expect(manifest['catalogCount'],229);
    final previous=jsonDecode(
      File('tool/visual_pilots/manifest.json').readAsStringSync());
    expect(previous['approved'],false);
    expect(previous['enabled'],false);
    expect(AnatomicalGlbStaging.stableIds,containsAll(ids));
  });
}
