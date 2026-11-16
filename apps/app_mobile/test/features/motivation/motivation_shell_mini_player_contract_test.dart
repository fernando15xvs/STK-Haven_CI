import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('mini-player belongs to shell layout above the dock, not an overlay',(){
    final shell=File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    expect(shell,contains('bottomNavigationBar: SafeArea('));
    expect(shell,contains('mainAxisSize:MainAxisSize.min'));
    expect(shell,contains('const MotivationHomeMiniPlayer()'));
    expect(shell,contains('_BottomBarSurface('));
    expect(shell.indexOf('const MotivationHomeMiniPlayer()'),
      lessThan(shell.indexOf('_BottomBarSurface(',shell.indexOf('bottomNavigationBar:'))));
    expect(shell,contains('body: IndexedStack('));
    expect(shell,contains('extendBody: false'));
  });

  test('compact player opens existing Now Playing and controls only shared audio',(){
    final mini=File(
      'lib/features/motivation/presentation/widgets/motivation_home_mini_player.dart',
    ).readAsStringSync();
    expect(mini,contains('MotivationPlayback.instance'));
    expect(mini,contains('AnimatedBuilder('));
    expect(mini,contains('player.currentTrack'));
    expect(mini,contains('player.completed'));
    expect(mini,contains('const SizedBox.shrink()'));
    expect(mini,contains('MotivationNowPlayingPage()'));
    expect(mini,contains("ValueKey('motivation_shell_mini_player')"));
    expect(mini,contains("ValueKey('motivation_shell_toggle')"));
    expect(mini,contains("ValueKey('motivation_shell_open_player')"));
    expect(mini,contains('maxLines:1'));
    expect(mini,contains('TextOverflow.ellipsis'));
    expect(mini,contains('minHeight:56'));
    expect(mini,contains('player.togglePlay()'));
    expect(mini,isNot(contains('OverlayEntry(')));
    expect(mini,isNot(contains('Stack(')));
    expect(mini,isNot(contains('audio.play()')));
    expect(mini,isNot(contains('AudioPlayer(')));
    expect(mini,isNot(contains('MotivationPage()')));
  });

  test('existing navigation retains one Motivation entry in the plus menu',(){
    final shell=File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    expect(shell.split("label: 'Motivation'").length-1,1);
    expect(shell.split('const MotivationPage()').length-1,1);
    expect(shell,contains('const MotivationHomeMiniPlayer()'));
  });
}
