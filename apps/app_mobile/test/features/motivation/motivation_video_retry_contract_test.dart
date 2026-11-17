import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('decoder failure has a manual retry and never creates another audio player',(){
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=page.indexOf('class _SilentVideoPreviewState');
    final end=page.indexOf('class _MotivationArtwork',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final video=page.substring(start,end);
    expect(video,contains('bool _videoFailed=false;'));
    expect(video,contains('if(controller!=null)return;'));
    expect(video,contains('await c.initialize();'));
    expect(video,contains('await c.setVolume(0);'));
    expect(video,contains('_videoFailed=true;'));
    expect(video,contains("ValueKey('motivation_video_decoder_error')"));
    expect(video,contains("ValueKey('motivation_video_retry')"));
    expect(video,contains('onPressed:()=>unawaited(_setup())'));
    expect(video,contains('void _markVideoDecoderFailed(VideoPlayerController c)'));
    expect(video,contains('if(!mounted || controller!=c)return;'));
    expect(video,contains('unawaited(c.dispose().catchError((Object _)'));
    expect(video,contains('c.addListener(_onVideoDecoderChanged);'));
    expect(video,contains('c.value.hasError'));
    expect(video,contains('_markVideoDecoderFailed(c);'));
    expect(video,contains('c.removeListener(_onVideoDecoderChanged);'));
    expect(video,contains('if(!visible){'));
    expect(video,contains('c.pause().catchError((Object _)'));
    expect(video,contains('_resumeVideoAfterForeground(c)'));
    expect(video,isNot(contains('AudioPlayer(')));
    expect(video,isNot(contains('VideoPlayerController.network')));
  });

  test('retry state resets when a new MP4 replaces the decoder',(){
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=page.indexOf('void _resetVideoSource()');
    final end=page.indexOf('Future<void> _setup() async',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final reset=page.substring(start,end);
    expect(reset,contains('_videoFailed=false;'));
    expect(reset,contains('controller=null;'));
    expect(reset,contains('_cinemaSource.value=null;'));
    expect(reset,contains('previous.removeListener(_onVideoDecoderChanged);'));
    expect(reset,contains('previous.dispose().catchError((Object _)'));
    expect(reset,contains('unawaited(_setup());'));
  });
}
