import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cinema reuses the only silent decoder and existing audio clock',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('void _openCinema()');
    final end=source.indexOf('Widget build(BuildContext context)',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final cinema=source.substring(start,end);
    expect(cinema,contains('valueListenable:_cinemaSource'));
    expect(cinema,contains('VideoPlayer(active)'));
    expect(cinema,isNot(contains('VideoPlayerController.file(')));
    expect(cinema,isNot(contains('AudioPlayer(')));
    expect(cinema,isNot(contains('audio.play()')));
    expect(source,contains('await c.setVolume(0)'));
    // Foreground/background handling belongs to the silent video widget,
    // not to the cinematic route. Check behavior rather than the obsolete
    // one-line pause syntax: native teardown errors must be swallowed.
    final lifecycleStart=source.indexOf(
      'void didChangeAppLifecycleState(AppLifecycleState state)',
      source.indexOf('class _SilentVideoPreviewState'));
    final resumeStart=source.indexOf(
      'Future<void> _resumeVideoAfterForeground(',lifecycleStart);
    final disposeStart=source.indexOf('void dispose(){',resumeStart);
    expect(lifecycleStart,greaterThanOrEqualTo(0));
    expect(resumeStart,greaterThan(lifecycleStart));
    expect(disposeStart,greaterThan(resumeStart));
    final lifecycle=source.substring(lifecycleStart,resumeStart);
    expect(lifecycle,contains('if(!visible){'));
    expect(lifecycle,contains('unawaited(c.pause().catchError((Object _)'));
    expect(lifecycle,contains('unawaited(_resumeVideoAfterForeground(c));'));
    final resume=source.substring(resumeStart,disposeStart);
    final seek=resume.indexOf('await c.seekTo(widget.playback.position);');
    final guard=resume.indexOf('if(!mounted || controller!=c || !visible)return;');
    final play=resume.indexOf('await c.play();');
    expect(seek,greaterThanOrEqualTo(0));
    expect(guard,greaterThan(seek));
    expect(play,greaterThan(guard));
    expect(resume,contains('widget.playback.playing && !widget.playback.completed'));
    expect(resume,isNot(contains('audio.play(')));
  });

  test('cinema controls are accessible and never start a second player',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('void _openCinema()');
    final end=source.indexOf('Widget build(BuildContext context)',start);
    final cinema=source.substring(start,end);
    expect(cinema,contains("ValueKey('motivation_cinema_shared_controls')"));
    expect(cinema,contains("ValueKey('motivation_cinema_toggle')"));
    expect(cinema,contains("tooltip:player.playing?'Pausar':'Reproducir'"));
    expect(cinema,contains('player.completed?Icons.replay_rounded'));
    expect(cinema,contains('player.canSkipNext'));
    expect(cinema,contains('player.togglePlay()'));
    expect(cinema,contains('player.previous()'));
    expect(cinema,contains('player.next()'));
    expect(cinema,contains("onPressed:player.canSkipNext"));
    expect(cinema,contains('SafeArea('));
    expect(cinema,contains('Expanded('));
    expect(cinema,contains('player.currentTrack?.title'));
  });
}
