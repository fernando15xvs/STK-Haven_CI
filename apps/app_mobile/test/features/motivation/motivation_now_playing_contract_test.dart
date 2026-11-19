import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/motivation/presentation/motivation_page.dart';

void main() {
  testWidgets('now playing has a safe empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MotivationNowPlayingPage(),
    ));
    expect(find.text('No hay archivos reproduciéndose.'), findsOneWidget);
    expect(find.text('STK Motivation'), findsOneWidget);
  });

  test('audio cover transitions respect reduce motion without resetting MP4',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(source,contains('AnimatedSwitcher('));
    expect(source,contains('MediaQuery.of(context).disableAnimations'));
    expect(source,contains("'now_playing_audio_art_"));
    expect(source,contains("key:const ValueKey('now_playing_video_shared')"));
    expect(source,contains('semanticFormatterCallback:(v)=>'));
    expect(source,contains('Comprueba el formato e inténtalo de nuevo.'));
    expect(source,isNot(contains('No se pudo actualizar la portada: ')));
  });

  test('library tap navigates to dedicated view, not an extra inline video', () {
    final source = File('lib/features/motivation/presentation/motivation_page.dart')
        .readAsStringSync();
    expect(source, contains('class MotivationNowPlayingPage'));
    expect(source, contains("key:const ValueKey('stk_now_playing_screen')"));
    expect(source, contains('onTap: () => unawaited(_playTrack(track, tracks))'));
    expect(source, contains("PopupMenuItem(value: 'cover'"));
    expect(source, contains('_MotivationArtwork(track: track, size: 52)'));
    expect(source, contains("maxHeight:artSize"));
    expect(source, contains('onPressed:_showQueue'));
    expect(source, contains('player.setRepeat(repeat)'));
    expect(source, contains('player.playAtIndex(i)'));
    expect(source, contains('void _openCinema()'));
    expect(source, contains('Ver video en pantalla completa'));
    expect(source.split('VideoPlayerController.file(').length-1, 1);
    expect(source, contains('onPressed:()=>unawaited(player.togglePlay())'));
  });
}
