import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/mobile_device_qa_probe.dart';

void main() {
  test('v9.7 bounded Flutter frame observations and RSS percentiles',() {
    final audit=GlbDeviceQaAccumulator(capacity:4);
    for(final us in [10000,18000,30000,45000,15000]) {
      audit.addFrame(totalUs:us,buildUs:us~/3,rasterUs:us~/2);
    }
    audit.observeRss(24*1024*1024);
    audit.observeRss(31*1024*1024);
    audit.observeRss(29*1024*1024);
    final s=audit.summary();
    expect(s['flutterFramesObserved'],5);
    expect(s['flutterFrameSamplesRetained'],4);
    expect(s['flutterTotalP50Us'],30000);
    expect(s['flutterTotalP95Us'],45000);
    expect(s['flutterTotalOver16667Us'],3);
    expect(s['flutterTotalOver33333Us'],1);
    expect(s['lastProcessRssBytes'],29*1024*1024);
    expect(s['maxObservedProcessRssBytes'],31*1024*1024);
    expect(s['residentMemoryObservations'],3);
    expect(s['frameMetric'],contains('not timed'));
    expect(()=>audit.addFrame(totalUs:-1,buildUs:0,rasterUs:0),
      throwsFormatException);
    expect(()=>audit.observeRss(-2),throwsFormatException);
    audit.reset();
    expect(audit.summary()['flutterFramesObserved'],0);
    expect(audit.summary()['maxObservedProcessRssBytes'],0);
  });

  test('v9.7 physical QA export never implies production approval',() {
    final session=GlbDeviceQaSession(
      accumulator:GlbDeviceQaAccumulator(capacity:12),
    );
    session.data.addFrame(totalUs:27000,buildUs:16000,rasterUs:11000);
    final decoded=jsonDecode(session.exportJson(
      sceneId:'ex_bench_press',
      scenario:'manual_device_preview',
      gpuChannelCounters:{'sent':4,'acknowledged':4},
    )) as Map<String,dynamic>;
    expect(decoded['schema'],'stk_mobile_anatomy_qa_v9_7');
    expect(decoded['approved'],false);
    expect(decoded['enabled'],false);
    expect(decoded['requiresPhysicalDeviceReview'],true);
    expect(decoded['notMeasured'],contains(
      'GPU presentation FPS or Android EGL swap completion',
    ));
    expect((decoded['nativeMethodChannel'] as Map)['sent'],4);
    expect((decoded['flutterFrameAndProcessMemory'] as Map)
      ['flutterFramesObserved'],1);
    expect(session.isRunning,false);
    session.dispose();
  });

  testWidgets('v9.7 device QA scheduler registers only if opted in',
      (tester) async {
    final qa=GlbDeviceQaSession();
    expect(qa.isRunning,false);
    qa.start();
    expect(qa.isRunning,true);
    qa.start();
    expect(qa.isRunning,true);
    qa.stop();
    expect(qa.isRunning,false);
    qa.dispose();
  });
}
