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
    expect(source,contains('if(!visible){unawaited(c.pause());}'));
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
