import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('changing MP4 track resets old native controller and listeners',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(code,contains('didUpdateWidget(covariant _SilentVideoPreview oldWidget)'));
    expect(code,contains('oldWidget.path != widget.path'));
    expect(code,contains('oldWidget.playback.removeListener(_syncVideoLoop)'));
    expect(code,contains('widget.playback.addListener(_syncVideoLoop)'));
    expect(code,contains('void _resetVideoSource()'));
    expect(code,contains('final ValueNotifier<VideoPlayerController?> _cinemaSource'));
    expect(code,contains('_cinemaSource.value=null;'));
    expect(code,contains('_cinemaSource.value=c;'));
    expect(code,contains('ValueListenableBuilder<VideoPlayerController?>'));
    expect(code,contains('child:VideoPlayer(active)'));
    expect(code,contains('position=null;'));
    expect(code,contains('playing=null;'));
    expect(code,contains('if(oldPosition!=null)unawaited(oldPosition.cancel())'));
    expect(code,contains('if(oldPlaying!=null)unawaited(oldPlaying.cancel())'));
    expect(code,contains('if(previous!=null)unawaited(previous.dispose())'));
    expect(code,contains('if(!mounted || controller!=c)return;'));
    expect(code,contains('if(!mounted || controller!=c ||'));
    expect(code.split('VideoPlayerController.file(').length-1,1);
  });

  test('silent video errors do not silently restart the audio clock',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(code,contains('await c.setVolume(0)'));
    expect(code,contains('state.processingState!=ProcessingState.completed'));
    expect(code,contains('.catchError((Object _)'));
  });
}
