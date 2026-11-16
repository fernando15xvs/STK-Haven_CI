import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeking is committed on release, not for each slider movement',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(code,contains("ValueKey('motivation_scrubber')"));
    expect(code,contains('onChangeStart:max==0?null:(v)=>'));
    expect(code,contains('onChanged:max==0?null:(v)=>'));
    expect(code,contains('setState(()=>_scrubMs=v)'));
    expect(code,contains('onChangeEnd:max==0?null:(v){'));
    expect(code,contains('unawaited(player.seek('));
    expect(code,isNot(contains('onChanged:max==0?null:(v)=>unawaited(')));
  });

  test('video clock seeks are throttled except for loop boundaries',(){
    final code=File(
      'lib/features/motivation/presentation/motivation_page.dart',
    ).readAsStringSync();
    expect(code,contains('DateTime? _lastPositionCorrection;'));
    expect(code,contains('loopJustRestarted=pos<'));
    expect(code,contains('elapsed>const Duration(milliseconds:900)'));
    expect(code,contains('drift>900 && !seeking'));
    expect(code,contains('_lastPositionCorrection=now;'));
  });
}
