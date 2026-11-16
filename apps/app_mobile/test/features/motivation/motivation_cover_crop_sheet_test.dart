import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_artwork_processor.dart';
import 'package:gym_tracker/features/motivation/presentation/widgets/motivation_cover_crop_sheet.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('canceling the optional cover sheet returns no crop',
      (tester) async {
    // A tiny, valid PNG fixture avoids awaiting Picture.toImage inside the
    // fake-async widget test zone (which previously hung for ten minutes).
    final folder=Directory.systemTemp.createTempSync('stk_cover_cancel_');
    try {
      final image=File('${folder.path}/preview.png');
      image.writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91Jpz'
        'AAAAFklEQVR4nGMUckthYGBgYmBgYGBgAAAIqADA5KefuAAAAABJRU5ErkJggg==',
      ));

      MotivationCoverFocus? result;
      var completed=false;
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:Builder(builder:(context)=>TextButton(
          onPressed:()async {
            result=await MotivationCoverCropSheet.show(context,image.path);
            completed=true;
          },
          child:const Text('Abrir editor'),
        )),
      )));
      await tester.tap(find.text('Abrir editor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds:400));
      expect(find.text('Ajustar portada'),findsOneWidget);
      expect(find.byKey(const ValueKey('motivation_crop_preview')),
        findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds:400));
      expect(completed,isTrue);
      expect(result,isNull);
      expect(find.text('Ajustar portada'),findsNothing);
      // Unmount the Image.file before deleting its temporary source.
      await tester.pumpWidget(const SizedBox.shrink());
    }finally{
      folder.deleteSync(recursive:true);
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
