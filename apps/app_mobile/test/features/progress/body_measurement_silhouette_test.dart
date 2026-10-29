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
  leftLegCm:55,rightLegCm:56,calvesCm:37);
final _newer=BodyMeasurement(
  id:'new',date:DateTime(2026,3,5),
  chestCm:101,leftArmCm:34,rightLegCm:57,
  waistCm:81,hipsCm:97,calvesCm:39);
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

  for(final dark in [false,true]) {
    testWidgets('front/back are simultaneously visible on 320px, theme $dark',
        (tester) async {
      tester.view.physicalSize=const Size(320,800);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected=MeasurementMetric.chest;
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(
          brightness:dark?Brightness.dark:Brightness.light,
          colorSchemeSeed:Colors.teal),
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
      expect(find.text('Frente'),findsOneWidget);
      expect(find.text('Espalda'),findsOneWidget);
      expect(find.text('101.0 cm'),findsWidgets);
      expect(find.byKey(const Key('silhouette_front')),findsOneWidget);
      expect(find.byKey(const Key('silhouette_back')),findsOneWidget);
      await tester.ensureVisible(find.byKey(
        const ValueKey('map_front_leftArm')));
      await tester.tap(find.byKey(const ValueKey('map_front_leftArm')));
      await tester.pumpAndSettle();
      expect(selected,MeasurementMetric.leftArm);
      expect(find.text('34.0 cm'),findsWidgets);
      expect(find.textContaining('+2.0 cm'),findsOneWidget);
      await tester.ensureVisible(find.byKey(
        const ValueKey('map_back_rightLeg')));
      await tester.tap(find.byKey(const ValueKey('map_back_rightLeg')));
      await tester.pumpAndSettle();
      expect(selected,MeasurementMetric.rightLeg);
      expect(find.textContaining('Anterior: 56.0 cm'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }


  for (final dark in [false, true]) {
    testWidgets('capture real Flutter front/back figure for artistic QA $dark',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          colorSchemeSeed: Colors.indigo),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const ValueKey('progress_measurement_map_snapshot'),
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
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('progress_measurement_map_snapshot')));
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('Failed to capture measurement figure');
          final dir = Directory('build/measurement_silhouette_qa')
            ..createSync(recursive: true);
          final file = File('${dir.path}/measurement_silhouette_${dark ? 'dark' : 'light'}.png');
          file.writeAsBytesSync(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          expect(file.lengthSync(), greaterThan(5000));
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty state shows no imaginary values and can select hips',
      (tester) async {
    var selected=MeasurementMetric.chest;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:StatefulBuilder(
        builder:(context,change)=>BodyMeasurementSilhouette(
          measurements:const [],selected:selected,
          onSelected:(metric)=>change(()=>selected=metric),
        ),
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin registro'),findsWidgets);
    expect(find.textContaining('Todavía no has registrado'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('measure_chip_hips')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('measure_chip_hips')));
    await tester.pumpAndSettle();
    expect(selected,MeasurementMetric.hips);
    expect(find.textContaining('Todavía no has registrado'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
