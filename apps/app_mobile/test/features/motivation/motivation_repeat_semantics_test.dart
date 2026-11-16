import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/data/motivation_library.dart';

void main() {
  test('four repeat modes tell the user their actual playback behavior',(){
    expect(MotivationRepeat.next.label,'Siguiente');
    expect(MotivationRepeat.one.label,'Repetir uno');
    expect(MotivationRepeat.all.label,'Repetir lista');
    expect(MotivationRepeat.stop.label,'Detener al finalizar');
    expect(MotivationRepeat.values.toSet(),hasLength(4));
  });

  test('native looping matches the selected mode without autoplay on change',(){
    final source=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(source,contains('MotivationRepeat.one=>LoopMode.one'));
    expect(source,contains('MotivationRepeat.all=>LoopMode.all'));
    expect(source,contains('MotivationRepeat.stop?[selected]:List.of(tracks)'));
    expect(source,contains('autoPlay:wasPlaying'));
    expect(source,contains('bool get completed => audio.processingState == ProcessingState.completed'));
    expect(source,contains('bool get playing => audio.playing && !completed'));
    expect(source,contains('if(completed) await audio.seek(Duration.zero)'));
  });

  test('a next tap at the end or in stop mode is disabled and safe',(){
    final playback=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(playback,contains('bool get canSkipNext =>'));
    expect(playback,contains('repeat != MotivationRepeat.stop && audio.hasNext'));
    expect(playback,contains('if(canSkipNext){'));
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(page,contains("ValueKey('motivation_next_track')"));
    expect(page,contains('onPressed:player.canSkipNext'));
    expect(page,contains("'No hay otra pista disponible'"));
    expect(page,contains("ValueKey('motivation_repeat_state')"));
    expect(page,contains("'Modo: ${player.repeat.label}'"));
    expect(page,contains('Semantics('));
    expect(page,contains('liveRegion:true'));
  });

  test('single-item shuffle and completed UI never impersonate active playback',(){
    final playback=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(playback,contains('bool get shuffleActive => shuffle && _queue.length > 1'));
    expect(playback,contains('if(_queue.length<2)return;'));
    final page=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(page,contains("tooltip:player.playing?'Pausar':'Reproducir'"));
    expect(page,contains('player.completed?Icons.replay_rounded'));
  });
}
