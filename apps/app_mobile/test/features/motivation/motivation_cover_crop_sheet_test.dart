import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_artwork_processor.dart';
import 'package:gym_tracker/features/motivation/presentation/widgets/motivation_cover_crop_sheet.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('canceling the optional cover sheet returns no crop',
      (tester) async {
    final folder=await Directory.systemTemp.createTemp('stk_cover_cancel_');
    try {
      final image=File('${folder.path}/preview.png');
      final recorder=ui.PictureRecorder();
      final picture=recorder.endRecording();
      final output=await picture.toImage(16,16);
      final png=(await output.toByteData(format:ui.ImageByteFormat.png))!;
      await image.writeAsBytes(png.buffer.asUint8List());
      output.dispose();
      picture.dispose();

      MotivationCoverFocus? result;
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:Builder(builder:(context)=>TextButton(
          onPressed:()async {
            result=await MotivationCoverCropSheet.show(context,image.path);
          },
          child:const Text('Abrir editor'),
        )),
      )));
      await tester.tap(find.text('Abrir editor'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar portada'),findsOneWidget);
      expect(find.byKey(const ValueKey('motivation_crop_preview')),
        findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result,isNull);
    }finally{
      await folder.delete(recursive:true);
    }
  });

  test('source is only written after a chosen focus, never on cancel',(){
    final source=File(
      'lib/features/motivation/data/motivation_library.dart',
    ).readAsStringSync();
    expect(source,contains('if(focus==null)return false;'));
    expect(source,contains('focus:focus'));
    expect(source,contains('MotivationArtworkProcessor.writeSquareCover('));
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(page.split('MotivationCoverCropSheet.show(').length-1,3);
  });
}
