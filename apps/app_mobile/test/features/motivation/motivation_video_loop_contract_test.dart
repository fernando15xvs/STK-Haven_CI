import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeat-one affects the silent MP4 decoder, not only just_audio', () {
    final page = File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();

    expect(page, contains('c.setLooping(widget.playback.repeat==MotivationRepeat.one)'));
    expect(page, contains('widget.playback.addListener(_syncVideoLoop)'));
    expect(page, contains('widget.playback.removeListener(_syncVideoLoop)'));
    expect(page, contains('c.value.isLooping!=loop'));
    expect(page, contains('state.processingState!=ProcessingState.completed'));
    expect(page, contains('await c.setVolume(0)'));
    expect(page, contains('widget.playback.audio.positionStream.listen'));
    expect(page, contains('unawaited(c.seekTo(pos).whenComplete(()'));
  });

  test('completed playback is not displayed as playing and rewinds to restart', () {
    final playback = File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(playback, contains('bool get completed => audio.processingState == ProcessingState.completed'));
    expect(playback, contains('bool get playing => audio.playing && !completed'));
    expect(playback, contains('if(completed) await audio.seek(Duration.zero)'));
    expect(playback, contains('MotivationRepeat.one=>LoopMode.one'));
    expect(playback, contains('MotivationRepeat.all=>LoopMode.all'));
    expect(playback, contains('await audio.setShuffleModeEnabled'));
    expect(playback, contains('bool get shuffleActive => shuffle && _queue.length > 1'));
    expect(playback, contains('if(_queue.length<2)return;'));
    final page=File('lib/features/motivation/presentation/motivation_page.dart').readAsStringSync();
    expect(page,contains('El modo aleatorio requiere dos pistas'));
    expect(page,contains('player.shuffleActive'));
    expect(page,contains('onPressed:player.queue.length<2?null:'));
  });
}
