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

  test('library tap navigates to dedicated view, not an extra inline video', () {
    final source = File('lib/features/motivation/presentation/motivation_page.dart')
        .readAsStringSync();
    expect(source, contains('class MotivationNowPlayingPage'));
    expect(source, contains("key:const ValueKey('stk_now_playing_screen')"));
    expect(source, contains('onTap:()=>unawaited(_playTrack(t,tracks))'));
    expect(source, contains("PopupMenuItem(value:'cover'"));
    expect(source, contains('_MotivationArtwork(track:t,size:52)'));
    expect(source, contains("maxHeight:artSize"));
    expect(source, contains('onPressed:_showQueue'));
    expect(source, contains('player.setRepeat(repeat)'));
    expect(source, contains('player.playAtIndex(i)'));
    expect(source, contains('onPressed:()=>unawaited(player.togglePlay())'));
  });
}
