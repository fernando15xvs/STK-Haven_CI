import 'package:core/core/constants/preset_exercises.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_png_pilot_library.dart';
import 'package:gym_tracker/features/exercises/presentation/widgets/exercise_demonstration_card.dart';

void main() {
  // The normal app intentionally hides these unapproved QA-only assets.
  // Run the remaining tests separately using --dart-define=STK_PNG_PILOTS=true.
  if (!PngPilotLibrary.enabled) {
    test('all unapproved PNG pilots are disabled in ordinary builds', () {
      expect(PngPilotLibrary.forId('ex_bench_press'),isNull);
      expect(PngPilotLibrary.forId('ex_barbell_row'),isNull);
      expect(PngPilotLibrary.forId('ex_squat'),isNull);
    });
    return;
  }
  test('pilots require explicit QA compilation and correct exercise IDs',(){
    expect(PngPilotLibrary.enabled,isTrue,
      reason:'Run only with --dart-define=STK_PNG_PILOTS=true');
    expect(PngPilotLibrary.pilots.keys.toSet(),
      {'ex_bench_press','ex_barbell_row','ex_squat'});
    expect(PngPilotLibrary.forId('ex_lateral_raises'),isNull);
    expect(PngPilotLibrary.forId('custom_123'),isNull);
    for(final exercise in PngPilotLibrary.pilots.values) {
      expect(exercise.stages.length,4);
      expect(exercise.primary,isNotEmpty);
      expect(exercise.secondary,isNotEmpty);
      for(var i=0;i<4;i++) {
        expect(exercise.imageAt(i),startsWith(
          'assets/exercise_media/png_pilots/${exercise.id}/'));
      }
    }
    expect(PngPilotLibrary.forId('ex_barbell_row')!.secondary,
      contains('Deltoides posterior'));
  });

  test('every bundled PNG is genuine and non-empty',() async {
    for(final pilot in PngPilotLibrary.pilots.values) {
      for(var i=0;i<pilot.stages.length;i++) {
        final data=await rootBundle.load(pilot.imageAt(i));
        final bytes=data.buffer.asUint8List(
          data.offsetInBytes,data.lengthInBytes);
        expect(bytes.length,greaterThan(2000));
        expect(bytes.sublist(0,8),
          [137,80,78,71,13,10,26,10]);
      }
    }
  });

  testWidgets('the same offline carousel appears in actual exercise card',
      (tester) async {
    tester.view.physicalSize=const Size(390,840);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for(final id in ['ex_bench_press','ex_barbell_row','ex_squat']) {
      final ex=presetExercises.firstWhere((x)=>x.id==id);
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:SingleChildScrollView(
          child:ExerciseDemonstrationCard(
            key:ValueKey(id),exercise:ex,reduceMotion:true)),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise_png_pilot_pages')),findsOneWidget);
      expect(find.textContaining('1 / 4'),findsOneWidget);
      expect(find.textContaining('Rojo · principales'),findsOneWidget);
      expect(find.textContaining('Azul · secundarios'),findsOneWidget);
      expect(find.byKey(const Key('exercise_media_fallback')),findsNothing);
      await tester.ensureVisible(find.byKey(const Key('exercise_png_next')));
      await tester.tap(find.byKey(const Key('exercise_png_next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 / 4'),findsOneWidget);
      expect(tester.takeException(),isNull);
    }
  });
}
