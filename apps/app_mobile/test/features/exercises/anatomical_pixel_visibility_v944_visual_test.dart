// STK Haven v9.44: quantify visible pixels, not merely valid GLB meshes.
// QA ONLY: all results are diagnostic, NOT professional artwork approval.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _root = 'build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916/hand_v917/contact_v918/'
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925/'
    'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932/'
    'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937/'
    'left_thumb_angle_v938/cuticles_v939/lower_leg_v940/torso_v941';
const _ids = ['ex_bench_press','ex_barbell_row','ex_squat'];
const _colors = <String, Color>{
  'STK_REGION_pectoralis_major': Color(0xFF2962FF),
  'STK_REGION_anterior_deltoid': Color(0xFF2962FF),
  'STK_REGION_latissimus_dorsi': Color(0xFF2962FF),
};
const _side = 360;
const _changeChannelThreshold = 3; // 8-bit raster change, not a visual verdict.
const _foregroundContrast = 12;
const _heuristicVisiblePercent = 0.5; // Review flag only; not a pass gate.
const _reportPath =
    'build/cc0_master_v7_flutter_qa/pixel_visibility_v944_report.json';

class _RgbaCapture {
  const _RgbaCapture(this.scale, this.bytes);
  final int scale;
  final Uint8List bytes;
}

Map<String, Object> _pixelDifference(Uint8List oldPixels,
    Uint8List newPixels, Color background, int scale) {
  final expected = _side * _side * scale * scale * 4;
  if (oldPixels.length != expected || newPixels.length != expected) {
    throw FormatException('Wrong RGBA pixel buffer shape at scale $scale');
  }
  final r = (background.r * 255).round();
  final g = (background.g * 255).round();
  final b = (background.b * 255).round();
  var foreground = 0;
  var changedForeground = 0;
  var maxDelta = 0;
  var changeOnBackground = 0;
  var totalAbsoluteDifference = 0;
  for (var i = 0; i < expected; i += 4) {
    final bgContrast = [
      (oldPixels[i] - r).abs(),
      (oldPixels[i + 1] - g).abs(),
      (oldPixels[i + 2] - b).abs(),
      (newPixels[i] - r).abs(),
      (newPixels[i + 1] - g).abs(),
      (newPixels[i + 2] - b).abs(),
    ].reduce(math.max);
    final delta = [
      (oldPixels[i] - newPixels[i]).abs(),
      (oldPixels[i + 1] - newPixels[i + 1]).abs(),
      (oldPixels[i + 2] - newPixels[i + 2]).abs(),
    ].reduce(math.max);
    if (bgContrast >= _foregroundContrast) {
      foreground += 1;
      totalAbsoluteDifference += delta;
      if (delta >= _changeChannelThreshold) changedForeground += 1;
      maxDelta = math.max(maxDelta, delta);
    } else if (delta >= _changeChannelThreshold) {
      changeOnBackground += 1;
    }
  }
  final ratio = foreground == 0 ? 0.0 : 100 * changedForeground / foreground;
  return <String, Object>{
    'devicePixelRatio': scale,
    'widthPx':_side * scale,
    'heightPx':_side * scale,
    'foregroundPixels':foreground,
    'changedForegroundPixels':changedForeground,
    'changedOnFlatBackgroundPixels':changeOnBackground,
    'changedForegroundPercent':double.parse(ratio.toStringAsFixed(5)),
    'meanMaxChannelDeltaInForeground':foreground == 0
        ? 0.0 : double.parse((totalAbsoluteDifference / foreground)
            .toStringAsFixed(5)),
    'peakChannelDelta':maxDelta,
    // Heuristic means `visible change might exist` only; NOT quality approval.
    'heuristicVisibleDifference':ratio >= _heuristicVisiblePercent,
  };
}

Future<List<_RgbaCapture>> _capture(WidgetTester tester,
    GlbDrawFrame frame, Color background) async {
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
    child:RepaintBoundary(
      key:const Key('v944_pixel_capture'),
      child:SizedBox(
        width:_side.toDouble(),height:_side.toDouble(),
        child:CustomPaint(painter:GlbSkinnedPainter(frame,background)),
      ),
    ),
  ))));
  await tester.pump();
  final result=await tester.runAsync(() async {
    final boundary=tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('v944_pixel_capture')));
    final output=<_RgbaCapture>[];
    for (final scale in [1,2]) {
      final image=await boundary.toImage(pixelRatio:scale.toDouble());
      try {
        final data=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
        if (data == null) throw StateError('Cannot render raw RGBA image');
        output.add(_RgbaCapture(scale,Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes))));
      } finally {
        image.dispose();
      }
    }
    return output;
  });
  if (result == null || result.length != 2) {
    throw StateError('Raster capture did not complete');
  }
  expect(tester.takeException(),isNull);
  return result;
}

void main() {
  late final Map<String,GlbSkinnedScene> previous;
  late final Map<String,GlbSkinnedScene> revised;
  setUpAll(() {
    previous={
      for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
          File('$_root/${id}_v941_torso_volume_mobile_qa.glb')
              .readAsBytesSync(),exerciseId:id),
    };
    revised={
      for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
          File('$_root/upper_v942/${id}_v942_upper_torso_mobile_qa.glb')
              .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa').createSync(recursive:true);
  });

  testWidgets('v9.44 pixel-level visibility diagnostics, 3 pilots x 2 '
      'themes x 3 poses x 2 resolutions', (tester) async {
    final rows=<Map<String,Object>>[];
    for(final id in _ids) {
      final a=previous[id]!;
      final b=revised[id]!;
      expect(a.containsRigidEquipment,true);
      expect(b.containsRigidEquipment,true);
      expect(a.triangleCount,b.triangleCount);
      for(final dark in [false,true]) {
        final background=dark
            ?const Color(0xFF111722):const Color(0xFFF2F5F8);
        for(final seconds in [0,2,4]) {
          const size=Size(360,360);
          final f0=a.frame(seconds.toDouble(),size,_colors,
              dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
          final f1=b.frame(seconds.toDouble(),size,_colors,
              dark:dark,poseNormals:true,depthSlices:6,zoom:1.2);
          expect(f0.finite,true);
          expect(f1.finite,true);
          final oldCaptures=await _capture(tester,f0,background);
          final newCaptures=await _capture(tester,f1,background);
          for(var index=0;index<oldCaptures.length;index++) {
            final scale=oldCaptures[index].scale;
            expect(newCaptures[index].scale,scale);
            final metrics=_pixelDifference(oldCaptures[index].bytes,
                newCaptures[index].bytes,background,scale);
            expect(metrics['foregroundPixels'],greaterThan(500));
            expect(metrics['peakChannelDelta'],inInclusiveRange(0,255));
            rows.add(<String,Object>{
              'exerciseId':id,
              'theme':dark?'dark':'light',
              'second':seconds,
              ...metrics,
            });
          }
        }
      }
    }
    expect(rows.length,36);
    final visible=rows.where(
        (m)=>m['heuristicVisibleDifference']==true).length;
    final report=<String,Object>{
      'schema':'stk_v944_real_flutter_pixel_visibility_qa',
      'comparison':'same camera, same exercise, v9.41 vs v9.42',
      'frameCount':18,
      'rasterComparisons':rows.length,
      'devicePixelRatios':[1,2],
      'catalogCount':229,
      'pilotCount':3,
      'visibleDifferenceHeuristicPercent':_heuristicVisiblePercent,
      'heuristicFlaggedComparisons':visible,
      'visualAppearanceProfessionallyApproved':false,
      'perceptualQualityCertified':false,
      'physicalDeviceReviewed':false,
      'productionReady':false,
      'approved':false,'enabled':false,
      'results':rows,
    };
    File(_reportPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report)+'\n');
    expect(File(_reportPath).existsSync(),true);
  },timeout:const Timeout(Duration(minutes:8)));
}
