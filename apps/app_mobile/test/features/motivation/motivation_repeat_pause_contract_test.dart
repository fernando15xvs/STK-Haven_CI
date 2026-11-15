import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('repeat-mode changes preserve pause and never transiently start sound',(){
    final source=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(source,contains('bool autoPlay=true'));
    expect(source,contains('if(autoPlay)unawaited(audio.play());'));
    expect(source,contains('autoPlay:wasPlaying'));
    expect(source,isNot(contains('if(!wasPlaying)await audio.pause();')));
    expect(source,contains('MotivationRepeat.one=>LoopMode.one'));
    expect(source,contains('MotivationRepeat.all=>LoopMode.all'));
  });
}
