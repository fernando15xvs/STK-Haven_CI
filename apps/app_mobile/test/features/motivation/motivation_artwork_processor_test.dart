import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_artwork_processor.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wide private cover is resized to a square local PNG',()async{
    final temp=await Directory.systemTemp.createTemp('stk_art_crop_');
    final input=File('${temp.path}/source.png');
    final output=File('${temp.path}/private-output.png');
    try{
      final recorder=ui.PictureRecorder();
      final canvas=ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0,0,600,300),
        ui.Paint()..color=const ui.Color(0xFF2671CC),
      );
      final picture=recorder.endRecording();
      final image=await picture.toImage(600,300);
      final bytes=(await image.toByteData(format:ui.ImageByteFormat.png))!;
      await input.writeAsBytes(bytes.buffer.asUint8List(),flush:true);
      image.dispose();
      picture.dispose();

      await MotivationArtworkProcessor.writeSquareCover(
        source:input,destination:output);
      expect(await output.exists(),isTrue);
      expect(await output.length(),
        lessThanOrEqualTo(MotivationArtworkProcessor.maxOutputBytes));
      final codec=await ui.instantiateImageCodec(await output.readAsBytes());
      final frame=await codec.getNextFrame();
      expect(frame.image.width,MotivationArtworkProcessor.squareSize);
      expect(frame.image.height,MotivationArtworkProcessor.squareSize);
      frame.image.dispose();
      codec.dispose();
    }finally{
      await temp.delete(recursive:true);
    }
  });


  test('horizontal crop focus uses selected left or right artwork',()async{
    final temp=await Directory.systemTemp.createTemp('stk_art_manual_crop_');
    try{
      final input=File('${temp.path}/wide.png');
      final leftFile=File('${temp.path}/left.png');
      final rightFile=File('${temp.path}/right.png');
      final recorder=ui.PictureRecorder();
      final canvas=ui.Canvas(recorder);
      canvas.drawRect(const ui.Rect.fromLTWH(0,0,300,300),
        ui.Paint()..color=const ui.Color(0xFFFF0000));
      canvas.drawRect(const ui.Rect.fromLTWH(300,0,300,300),
        ui.Paint()..color=const ui.Color(0xFF0000FF));
      final picture=recorder.endRecording();
      final image=await picture.toImage(600,300);
      final raw=(await image.toByteData(format:ui.ImageByteFormat.png))!;
      await input.writeAsBytes(raw.buffer.asUint8List(),flush:true);
      image.dispose();
      picture.dispose();

      await MotivationArtworkProcessor.writeSquareCover(
        source:input,destination:leftFile,
        focus:const MotivationCoverFocus(x:-1));
      await MotivationArtworkProcessor.writeSquareCover(
        source:input,destination:rightFile,
        focus:const MotivationCoverFocus(x:1));
      Future<List<int>> pixel(File file) async {
        final codec=await ui.instantiateImageCodec(await file.readAsBytes());
        final frame=await codec.getNextFrame();
        final rgba=(await frame.image.toByteData(
          format:ui.ImageByteFormat.rawRgba))!;
        const offset=(256*512+256)*4;
        final color=[
          rgba.getUint8(offset),
          rgba.getUint8(offset+1),
          rgba.getUint8(offset+2),
        ];
        frame.image.dispose();
        codec.dispose();
        return color;
      }
      final l=await pixel(leftFile);
      final r=await pixel(rightFile);
      expect(l[0],greaterThan(240));
      expect(l[2],lessThan(15));
      expect(r[0],lessThan(15));
      expect(r[2],greaterThan(240));
    }finally{
      await temp.delete(recursive:true);
    }
  });

  test('bad crop offsets safely fall back to center',(){
    const invalid=MotivationCoverFocus(x:double.nan,y:double.infinity);
    expect(invalid.safeX,0);
    expect(invalid.safeY,0);
    const outside=MotivationCoverFocus(x:200,y:-100);
    expect(outside.safeX,1);
    expect(outside.safeY,-1);
  });

  test('invalid private image is rejected without writing a cover',()async{
    final temp=await Directory.systemTemp.createTemp('stk_art_invalid_');
    try{
      final source=File('${temp.path}/broken.jpg');
      final destination=File('${temp.path}/output.png');
      await source.writeAsBytes([0,1,2,3,4]);
      expect(
        ()=>MotivationArtworkProcessor.writeSquareCover(
          source:source,destination:destination),
        throwsA(isA<Exception>()),
      );
      expect(await destination.exists(),isFalse);
    }finally{
      await temp.delete(recursive:true);
    }
  });
}
