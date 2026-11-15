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
