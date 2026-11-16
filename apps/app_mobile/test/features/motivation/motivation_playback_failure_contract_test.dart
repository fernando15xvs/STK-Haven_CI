import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('unsupported local media clears stale queue and sound',(){
    final source=File(
      'lib/features/motivation/application/motivation_playback.dart',
    ).readAsStringSync();
    expect(source,contains('await audio.stop();'));
    expect(source,contains('_queue=[];'));
    expect(source,contains('_original=[];'));
    expect(source,contains('Comprueba si su formato es compatible.'));
    expect(source,isNot(contains('Comprueba el códec:')));
  });

  test('library shows a user error instead of opening an empty player',(){
    final source=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(source,contains('if(player.error!=null){'));
    expect(source,contains('_message(player.error!);'));
    expect(source,contains('if(player.currentTrack!=null)_openNowPlaying();'));
  });
}
