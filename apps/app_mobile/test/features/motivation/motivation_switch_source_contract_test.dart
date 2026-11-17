import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('changing MP4 track resets old native controller and listeners',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(code,contains('didUpdateWidget(covariant _SilentVideoPreview oldWidget)'));
    // A changing key would dispose the previous state instead of invoking
    // didUpdateWidget; the cinema route would then hold a stale source.
    expect(code,contains("key:const ValueKey('now_playing_video_shared')"));
    expect(code,isNot(contains("key:ValueKey('now_playing_video_\${track.id}')")));
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

  test('asynchronous MP4 setup cannot publish a replaced decoder',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=code.indexOf('Future<void> _setup() async');
    final end=code.indexOf('void _syncVideoLoop()',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final setup=code.substring(start,end);
    // Guard after initialize, setVolume, setLooping and seekTo.
    expect(setup.split('if(!mounted || controller!=c)return;').length-1,
      greaterThanOrEqualTo(4));
    expect(setup,contains('if(controller==c)seeking=false;'));
    expect(setup,contains('if(!mounted || controller!=c ||'));
    expect(setup,contains('position=widget.playback.audio.positionStream.listen'));
    expect(setup,contains('playing=widget.playback.audio.playerStateStream.listen'));
    // No old decoder may publish to cinema after source replacement.
    expect(setup.lastIndexOf('if(!mounted || controller!=c)return;'),
      lessThan(setup.indexOf('_cinemaSource.value=c;')));
  });

  test('foreground MP4 resync seeks before play and rejects stale controllers',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=code.indexOf(
      'Future<void> _resumeVideoAfterForeground(VideoPlayerController c) async');
    final end=code.indexOf('  @override\n  void dispose()',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final resume=code.substring(start,end);
    final seek=resume.indexOf('await c.seekTo(widget.playback.position);');
    final guard=resume.indexOf('if(!mounted || controller!=c || !visible)return;');
    final play=resume.indexOf('await c.play();');
    expect(seek,greaterThanOrEqualTo(0));
    expect(guard,greaterThan(seek));
    expect(play,greaterThan(guard));
    expect(resume,contains(
      'if(widget.playback.playing && !widget.playback.completed)'));
    expect(resume,contains('}catch(_){'));
    // The silent video must never start, seek or stop the shared audio clock.
    expect(resume,isNot(contains('audio.play(')));
    expect(resume,isNot(contains('audio.seek(')));
    expect(resume,isNot(contains('audio.stop(')));
  });

  test('cinema shared controls remain scrollable with 200% accessibility text',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=code.indexOf('void _openCinema()');
    final end=code.indexOf('  @override\n  Widget build(BuildContext context){',start);
    final cinema=code.substring(start,end);
    expect(cinema,contains('Flexible(fit:FlexFit.loose,'));
    expect(cinema,contains('child:AnimatedBuilder('));
    expect(cinema,contains('return SingleChildScrollView('));
    expect(cinema,contains("ValueKey('motivation_cinema_shared_controls')"));
    expect(cinema,contains("ValueKey('motivation_cinema_toggle')"));
    expect(cinema,isNot(contains('VideoPlayerController.file(')));
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
