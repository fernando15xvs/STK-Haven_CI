import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Offline artwork normalization. Never uploads photos or creates remote URLs.
///
/// Large JPEG/PNG/WebP selections become an efficient 512×512 PNG center crop,
/// not a full-resolution image decoded on every STK Motivation list row.
/// This is a deterministic default crop; manual repositioning remains a
/// separate, explicitly pending interface feature.
class MotivationArtworkProcessor {
  const MotivationArtworkProcessor._();

  static const maxInputBytes=8*1024*1024;
  static const maxOutputBytes=2*1024*1024;
  static const squareSize=512;

  static Future<void> writeSquareCover({
    required File source,
    required File destination,
  }) async {
    final bytes=await source.readAsBytes();
    if(bytes.isEmpty || bytes.length>maxInputBytes){
      throw const FormatException('Portada vacía o mayor a 8 MB');
    }
    final codec=await ui.instantiateImageCodec(bytes,targetWidth:720);
    try{
      final frame=await codec.getNextFrame();
      final original=frame.image;
      try{
        final shortest=math.min(original.width,original.height).toDouble();
        if(shortest<=0)throw const FormatException('Imagen no válida');
        final left=(original.width-shortest)/2;
        final top=(original.height-shortest)/2;
        final recorder=ui.PictureRecorder();
        final canvas=ui.Canvas(recorder);
        canvas.drawImageRect(
          original,
          ui.Rect.fromLTWH(left,top,shortest,shortest),
          const ui.Rect.fromLTWH(0,0,squareSize.toDouble(),squareSize.toDouble()),
          ui.Paint()..filterQuality=ui.FilterQuality.high,
        );
        final picture=recorder.endRecording();
        try{
          final resized=await picture.toImage(squareSize,squareSize);
          try{
            final buffer=await resized.toByteData(format:ui.ImageByteFormat.png);
            if(buffer==null ||
               buffer.lengthInBytes==0 ||
               buffer.lengthInBytes>maxOutputBytes){
              throw const FormatException('No se pudo optimizar la portada');
            }
            await destination.writeAsBytes(
              buffer.buffer.asUint8List(),flush:true);
          }finally{
            resized.dispose();
          }
        }finally{
          picture.dispose();
        }
      }finally{
        original.dispose();
      }
    }finally{
      codec.dispose();
    }
  }
}
