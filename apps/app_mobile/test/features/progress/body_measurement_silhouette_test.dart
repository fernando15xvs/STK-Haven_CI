import 'dart:io';
import 'dart:ui' as ui;
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_anatomy_vector_data.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

final _older=BodyMeasurement(
  id:'old',date:DateTime(2026,1,5),
  chestCm:97,shouldersCm:114,leftArmCm:32,rightArmCm:33,
  leftLegCm:55,rightLegCm:56,calvesCm:37,
  neckCm:38,leftForearmCm:28,rightForearmCm:29,leftCalfCm:34,rightCalfCm:35);
final _newer=BodyMeasurement(
  id:'new',date:DateTime(2026,3,5),
  chestCm:101,leftArmCm:34,rightLegCm:57,
  waistCm:81,hipsCm:97,calvesCm:39,rightCalfCm:38);
final _latestPartial=BodyMeasurement(
  id:'partial',date:DateTime(2026,4,5),
  weightKg:78,bodyFatPercentage:17.2,waistCm:80);

void main() {
  test('original 2D anatomy has real SVG assets and matching native contours',
      () async {
    expect(anatomyFrontContours.length, greaterThan(30));
    expect(anatomyBackContours.length, greaterThan(30));
    for (final side in ['front','back']) {
      final svg = await rootBundle.loadString(
          'assets/measurement_anatomy/stk_anatomy_$side.svg');
      expect(svg,contains('<svg'));
      expect(svg,contains('viewBox="0 0 200 440"'));
      expect(svg,contains('fill="#111318"'));
      expect(svg,contains('stroke="#F6F8FA"'));
      final contours = side == 'front' ?
        anatomyFrontContours : anatomyBackContours;
      for (final contour in contours) {
        expect(svg.contains('d="${contour.d}"'),isTrue,
            reason:'SVG artwork and Flutter native vector must agree');
      }
    }
  });

  test('latest valid non-null measurement is selected independently', () {
    const get=SilhouetteMeasurementData.latest;
    final samples=[_older,_newer,_latestPartial];
    expect(get(samples,MeasurementMetric.chest)!.value,101);
    expect(get(samples,MeasurementMetric.chest)!.previous,97);
    expect(get(samples,MeasurementMetric.chest)!.delta,4);
    expect(get(samples,MeasurementMetric.waist)!.value,80);
    expect(get(samples,MeasurementMetric.waist)!.previous,81);
    expect(get(samples,MeasurementMetric.shoulders)!.value,114);
    expect(get(samples,MeasurementMetric.shoulders)!.previous,isNull);
    expect(get(samples,MeasurementMetric.leftLeg)!.value,55);
    expect(get(samples,MeasurementMetric.rightLeg)!.value,57);
    expect(get(samples,MeasurementMetric.calves)!.value,39);
    expect(get(samples,MeasurementMetric.leftCalf)!.value,34);
    expect(get(samples,MeasurementMetric.rightCalf)!.value,38);
    expect(get(samples,MeasurementMetric.rightCalf)!.previous,35);
    expect(get(samples,MeasurementMetric.neck)!.value,38);
    expect(get([],MeasurementMetric.chest),isNull);
    expect(SilhouetteMeasurementData.metrics, isNot(contains(MeasurementMetric.weight)));
    expect(SilhouetteMeasurementData.metrics, isNot(contains(MeasurementMetric.bodyFat)));
  });

  test('same-day records are not treated as earlier history; invalid values ignored',(){
    final date=DateTime(2026,2,1);
    final rows=[
      BodyMeasurement(id:'x',date:date,leftArmCm:31),
      BodyMeasurement(id:'y',date:date,leftArmCm:32),
      BodyMeasurement(id:'bad',date:date.add(const Duration(days:1)),
        leftArmCm:double.nan),
    ];
    final data=SilhouetteMeasurementData.latest(rows,MeasurementMetric.leftArm)!;
    expect(data.value,isIn([31,32]));
    expect(data.previous,isNull);
  });


  test('eleven transparent anatomical PNG assets are bundled', () async {
    const files = [
      'body_front','body_back','detail_chest','detail_shoulders',
      'detail_waist','detail_hips','detail_left_arm',
      'detail_right_arm','detail_left_leg','detail_right_leg','detail_calves',
    ];
    for (final name in files) {
      final buffer = await rootBundle.load(
        'assets/measurement_anatomy/png/$name.png',
      );
      final bytes = buffer.buffer.asUint8List(
        buffer.offsetInBytes,buffer.lengthInBytes,
      );
      expect(bytes.length,greaterThan(10000),reason:name);
      expect(bytes.sublist(0,8),[137,80,78,71,13,10,26,10],reason:name);
    }
  });

  for (final dark in [false,true]) {
    testWidgets('PNG front/back switch and muscle details on 320px $dark',
        (tester) async {
      tester.view.physicalSize=const Size(320,850);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected=MeasurementMetric.chest;
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(brightness:dark?Brightness.dark:Brightness.light,
          colorSchemeSeed:Colors.blue),
        home:Scaffold(body:SingleChildScrollView(
          child:StatefulBuilder(builder:(context,setState)=>
            BodyMeasurementSilhouette(
              measurements:[_older,_newer,_latestPartial],
              selected:selected,
              onSelected:(metric)=>setState(()=>selected=metric),
            ),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('silhouette_front')),findsOneWidget);
      expect(find.byKey(const Key('silhouette_back')),findsNothing);
      expect(find.byKey(const Key('measurement_anatomy_png')),findsOneWidget);
      expect(find.byKey(const Key('measure_chip_chest')),findsOneWidget);
      expect(find.byKey(const Key('measure_chip_neck')),findsNothing);
      expect(find.byKey(const Key('measure_chip_leftForearm')),findsNothing);
      expect(find.byKey(const Key('map_front_neck')),findsOneWidget);
      expect(find.byKey(const Key('map_front_leftForearm')),findsOneWidget);
      expect(find.byKey(const Key('measure_chip_leftCalf')),findsNothing);
      expect(find.text('101.0 cm'),findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('measure_chip_chest')));
      await tester.tap(find.byKey(const Key('measure_chip_chest')));
      await tester.pumpAndSettle();
      expect(find.byType(MeasurementMuscleDetailPage),findsOneWidget);
      expect(find.text('101.0 cm'),findsWidgets);
      expect(find.byKey(const Key('measurement_detail_chart')),findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('measurement_show_all')));
      await tester.tap(find.byKey(const Key('measurement_show_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measurement_all_contours_list')),findsOneWidget);
      expect(find.byKey(const Key('measurement_all_neck')),findsOneWidget);
      await tester.tap(find.byKey(const Key('measurement_all_neck')));
      await tester.pumpAndSettle();
      expect(find.byType(MeasurementMuscleDetailPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Espalda').last);
      await tester.tap(find.text('Espalda').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('silhouette_back')),findsOneWidget);
      expect(find.byKey(const Key('silhouette_front')),findsNothing);
      expect(find.byKey(const Key('measure_chip_chest')),findsNothing);
      expect(find.byKey(const Key('measure_chip_calves')),findsNothing);
      await tester.ensureVisible(find.byKey(const Key('measure_chip_rightCalf')));
      await tester.tap(find.byKey(const Key('measure_chip_rightCalf')));
      await tester.pumpAndSettle();
      expect(selected,MeasurementMetric.rightCalf);
      expect(find.text('38.0 cm'),findsWidgets);
      expect(find.textContaining('Anterior: 35.0 cm'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }

  for (final dark in [false,true]) {
    testWidgets('capture both real PNG views from Flutter $dark',
        (tester) async {
      tester.view.physicalSize = const Size(390,1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(brightness:dark?Brightness.dark:Brightness.light,
          colorSchemeSeed:Colors.blue),
        home:Scaffold(body:SingleChildScrollView(
          child:RepaintBoundary(
            key:const Key('progress_measurement_map_snapshot'),
            child:BodyMeasurementSilhouette(
              measurements:[_older,_newer,_latestPartial],
              selected:MeasurementMetric.chest,
              onSelected:(_){},
            ),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      for (final side in ['front','back']) {
        if(side=='back') {
          await tester.ensureVisible(find.text('Espalda').last);
          await tester.tap(find.text('Espalda').last);
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('progress_measurement_map_snapshot')));
          final image=await boundary.toImage(pixelRatio:2);
          try {
            final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
            expect(bytes,isNotNull);
            final dir=Directory('build/measurement_silhouette_qa')
              ..createSync(recursive:true);
            final file=File('${dir.path}/measurement_png_${dark?'dark':'light'}_$side.png');
            file.writeAsBytesSync(bytes!.buffer.asUint8List(
              bytes.offsetInBytes,bytes.lengthInBytes));
            expect(file.lengthSync(),greaterThan(5000));
          } finally {
            image.dispose();
          }
        });
      }
      expect(tester.takeException(),isNull);
    });
  }

  testWidgets('empty state does not invent a measurement', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:BodyMeasurementSilhouette(
        measurements:const [],
        selected:MeasurementMetric.chest,
        onSelected:(_){},
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('silhouette_front')),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('measure_chip_chest')));
    await tester.tap(find.byKey(const Key('measure_chip_chest')));
    await tester.pumpAndSettle();
    expect(find.text('Sin registros todavía.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  // Regression for the iPhone screenshots: prior markers were on the
  // pectoral (shoulders), upper abdomen (chest), glutes (waist), knees
  // (thighs) and lower legs (calves). Verify image-relative anatomy, not
  // just labels and links, across compact and enlarged typography.
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('anatomy landmarks at ${width.toInt()}px x $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1050);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: BodyMeasurementSilhouette(
                  measurements: [_older, _newer, _latestPartial],
                  selected: MeasurementMetric.chest,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        void check(String side, Map<String, Offset> landmarks) {
          final figure = tester.getRect(
            find.byKey(const Key('measurement_anatomy_png')));
          for (final item in landmarks.entries) {
            final target = find.byKey(Key('map_${side}_${item.key}'));
            expect(target, findsOneWidget,
                reason: 'Missing ${side} / ${item.key}');
            final center = tester.getCenter(target);
            final actual = Offset(
              (center.dx - figure.left) / figure.width,
              (center.dy - figure.top) / figure.height,
            );
            expect(actual.dx, closeTo(item.value.dx, .03),
                reason: 'Horizontal anatomy error: ${side} ${item.key}');
            expect(actual.dy, closeTo(item.value.dy, .03),
                reason: 'Vertical anatomy error: ${side} ${item.key}');
          }
        }

        check('front', {
          'neck': const Offset(.50, .166),
          'shoulders': const Offset(.82, .190),
          'chest': const Offset(.50, .245),
          'rightArm': const Offset(.215, .300),
          'leftArm': const Offset(.785, .300),
          'rightForearm': const Offset(.165, .385),
          'leftForearm': const Offset(.835, .385),
          'rightLeg': const Offset(.415, .535),
          'leftLeg': const Offset(.585, .535),
        });
        final frontShoulder = tester.getCenter(
          find.byKey(const Key('map_front_shoulders')));
        final frontChest = tester.getCenter(
          find.byKey(const Key('map_front_chest')));
        expect(frontShoulder.dx, greaterThan(frontChest.dx),
            reason: 'Deltoid must be lateral to pectoral');
        expect(frontShoulder.dy, lessThan(frontChest.dy),
            reason: 'Deltoid is not the lower pectoral');

        await tester.ensureVisible(find.text('Espalda').last);
        await tester.tap(find.text('Espalda').last);
        await tester.pumpAndSettle();
        check('back', {
          'waist': const Offset(.50, .360),
          'hips': const Offset(.54, .460),
          'rightCalf': const Offset(.60, .730),
          'leftCalf': const Offset(.40, .730),
        });
        expect(tester.getCenter(find.byKey(const Key('map_back_waist'))).dy,
            lessThan(tester.getCenter(
                find.byKey(const Key('map_back_hips'))).dy));
        expect(tester.getCenter(find.byKey(const Key('map_back_hips'))).dy,
            lessThan(tester.getCenter(
                find.byKey(const Key('map_back_leftCalf'))).dy));
        expect(tester.takeException(), isNull);
      });
    }
  }

}
