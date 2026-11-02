// STK Haven v9.45: actual full-body vs anatomical-focus Flutter review.
// QA ONLY. Larger on-screen anatomy is NOT professional muscle geometry.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _root='build/cc0_master_surface_v7/v8_authoring/'
    'detail_bake_v915/torso_v916/hand_v917/contact_v918/'
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925/'
    'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932/'
    'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937/'
    'left_thumb_angle_v938/cuticles_v939/lower_leg_v940/'
    'torso_v941/upper_v942';
const _ids=['ex_bench_press','ex_barbell_row','ex_squat'];
const _palette=<Color>[
  Color(0xFF2962FF),Color(0xFF00A3A3),Color(0xFFE67722),
  Color(0xFF7A4DCA),Color(0xFFE84378),Color(0xFF23A55A),
  Color(0xFFF0B429),Color(0xFF475569),
];
const _side=360;
const _overviewZoom=1.2;
const _focusZoom=.72;
const _minimumMagnificationRatio=1.10;

Map<String,Color> _theme(Color accent) => <String,Color>{
  'STK_REGION_pectoralis_major':accent,
  'STK_REGION_anterior_deltoid':accent,
  'STK_REGION_posterior_deltoid':accent,
  'STK_REGION_latissimus_dorsi':accent,
  'STK_REGION_rhomboids':accent,
  'STK_REGION_middle_trapezius':accent,
};

class _Pixels {
  const _Pixels(this.png,this.foreground,this.edgeInk);
  final Uint8List png;
  final int foreground,edgeInk;
}

/// Count rendered pixels so a cropped or tiny QA model cannot pass silently.
_Pixels _measure(ByteData raw, Uint8List png, Color background) {
  final bytes=raw.buffer.asUint8List(raw.offsetInBytes,raw.lengthInBytes);
  if(bytes.length!=_side*_side*4) {
    throw const FormatException('Unexpected RGBA image dimensions');
  }
  final r=(background.r*255).round();
  final g=(background.g*255).round();
  final b=(background.b*255).round();
  var foreground=0,edgeInk=0;
  for(var index=0;index<bytes.length;index+=4) {
    final delta=math.max((bytes[index]-r).abs(),
        math.max((bytes[index+1]-g).abs(),(bytes[index+2]-b).abs()));
    if(delta<12)continue;
    foreground++;
    final pixel=index~/4;
    final x=pixel%_side,y=pixel~/_side;
    if(x<3||x>=_side-3||y<3||y>=_side-3)edgeInk++;
  }
  return _Pixels(png,foreground,edgeInk);
}

Future<_Pixels> _paintCapture(WidgetTester tester,GlbDrawFrame frame,
    Color background) async {
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
    child:RepaintBoundary(key:const Key('v945_surface'),
      child:SizedBox(width:360,height:360,child:CustomPaint(
        painter:GlbSkinnedPainter(frame,background))),
    ),
  ))));
  await tester.pump();
  final shot=await tester.runAsync(() async {
    final boundary=tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('v945_surface')));
    final image=await boundary.toImage(pixelRatio:1);
    try {
      final rgba=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
      final png=await image.toByteData(format:ui.ImageByteFormat.png);
      if(rgba==null||png==null) {
        throw StateError('Failed QA-only Flutter raster capture');
      }
      return _measure(rgba,Uint8List.fromList(
          png.buffer.asUint8List(png.offsetInBytes,png.lengthInBytes)),
          background);
    } finally {
      image.dispose();
    }
  });
  if(shot==null)throw StateError('QA capture returned no image');
  expect(tester.takeException(),isNull);
  return shot;
}

void main() {
  late final Map<String,GlbSkinnedScene> scenes;
  setUpAll(() {
    scenes={
      for(final id in _ids) id:GlbSkinnedScene.decodeMasterExercise(
          File('$_root/${id}_v942_upper_torso_mobile_qa.glb')
              .readAsBytesSync(),exerciseId:id),
    };
    Directory('build/cc0_master_v7_flutter_qa')
        .createSync(recursive:true);
  });

  test('v9.45 non-production focus camera honors eight accents and views',(){
    for(final id in _ids) {
      final scene=scenes[id]!;
      for(final color in _palette) {
        for(final dark in [false,true]) {
          for(final orbit in [-.45,.45]) {
            final frame=scene.frame(2.0,const Size(360,360),_theme(color),
              dark:dark,orbit:orbit,zoom:_focusZoom,
              poseNormals:true,depthSlices:6);
            expect(frame.finite,true);
            expect(scene.containsRigidEquipment,true);
          }
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));

  testWidgets('v9.45 12 readable full-vs-focus review pairs with evidence',
      (tester) async {
    final data=<Map<String,Object>>[];
    for(final id in _ids) {
      final scene=scenes[id]!;
      for(final dark in [false,true]) {
        final background=dark
            ?const Color(0xFF111722):const Color(0xFFF2F5F8);
        for(final orbit in [-.45,.45]) {
          final wide=scene.frame(2.0,const Size(360,360),
              _theme(_palette.first),dark:dark,orbit:orbit,
              zoom:_overviewZoom,poseNormals:true,depthSlices:6);
          final close=scene.frame(2.0,const Size(360,360),
              _theme(_palette.first),dark:dark,orbit:orbit,
              zoom:_focusZoom,poseNormals:true,depthSlices:6);
          expect(wide.finite,true);
          expect(close.finite,true);
          final a=await _paintCapture(tester,wide,background);
          final b=await _paintCapture(tester,close,background);
          expect(a.foreground,greaterThan(600));
          expect(b.foreground,greaterThan(600));
          final ratio=b.foreground/a.foreground;
          // This tests presentation scale, NOT anatomical correctness.
          expect(ratio,greaterThan(_minimumMagnificationRatio),
              reason:'Anatomical focus must expose more actual screen area');
          final darkName=dark?'dark':'light';
          final side=orbit>0?'right':'left';
          final filename='v945_${id}_${darkName}_${side}';
          File('build/cc0_master_v7_flutter_qa/${filename}_wide.png')
              .writeAsBytesSync(a.png);
          File('build/cc0_master_v7_flutter_qa/${filename}_focus.png')
              .writeAsBytesSync(b.png);
          data.add(<String,Object>{
            'exerciseId':id,'theme':darkName,
            'view':side,'wideForegroundPixels':a.foreground,
            'focusForegroundPixels':b.foreground,
            'focusToOverviewForegroundRatio':double.parse(
                ratio.toStringAsFixed(5)),
            'wideEdgePixels':a.edgeInk,
            'focusEdgePixels':b.edgeInk,
            'cameraWideZoom':_overviewZoom,
            'cameraFocusZoom':_focusZoom,
            'detailMayCropRigidEquipment':b.edgeInk>0,
          });
        }
      }
    }
    expect(data.length,12);
    final report=<String,Object>{
      'schema':'stk_v945_anatomy_focus_flutter_raster_qa',
      'sourceVersion':942,'catalogCount':229,'pilotCount':3,
      'comparisonCount':12,'frameSeconds':2.0,
      'views':['left','right'],'modes':['light','dark'],
      'minimumFocusMagnificationRatio':_minimumMagnificationRatio,
      'visibleSculptDeltaAtDpr1UnderHalfPercentInV944':true,
      'note':'Closer camera improves review size, not mesh anatomy.',
      'technicalArtistReviewComplete':false,
      'biomechanicsCertified':false,
      'physicalDeviceTested':false,'productionReady':false,
      'approved':false,'enabled':false,
      'samples':data,
    };
    File('build/cc0_master_v7_flutter_qa/focus_v945_report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ')
            .convert(report)+'\n');
  },timeout:const Timeout(Duration(minutes:8)));
}
