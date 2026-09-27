import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('browser Back is guarded instead of popping Flutter routes', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('let stkHistoryGuardReady = false;'));
    expect(html, contains('stkHavenBackGuard: true'));
    expect(html, contains("window.addEventListener('popstate', (event) => {"));
    expect(html, contains('event.stopImmediatePropagation();'));

    // Browser Back must never be translated into a Flutter Navigator pop.
    expect(html, isNot(contains('stkFlutterBackHandler')));
    expect(html, isNot(contains('stkHistoryRoutePushed')));
    expect(html, isNot(contains('stkHistoryRoutePopped')));
  });

  test('history guard stays same-document and never traverses browser history',
      () {
    final html = File('web/index.html').readAsStringSync();
    final initStart = html.indexOf('window.stkHistoryInitialize = () => {');
    final helperStart = html.indexOf(
      '    function stkUrlBase64ToUint8Array',
      initStart,
    );

    expect(initStart, greaterThanOrEqualTo(0));
    expect(helperStart, greaterThan(initStart));

    final historyBridge = html.substring(initStart, helperStart);
    expect(historyBridge, contains('history.replaceState('));
    expect(historyBridge, contains('history.pushState('));
    expect(historyBridge, isNot(contains('history.back()')));
    expect(historyBridge, isNot(contains('history.go(')));
    expect(historyBridge, isNot(contains('history.forward()')));
  });

  test('Dart bridge does not observe route pushes or pops', () {
    final bridge = File(
      'lib/core/navigation/web_browser_history_bridge.dart',
    ).readAsStringSync();

    expect(bridge, contains('_stkHistoryInitialize();'));
    expect(bridge, isNot(contains('didPush(')));
    expect(bridge, isNot(contains('didPop(')));
    expect(bridge, isNot(contains('removeRoute(')));
    expect(bridge, isNot(contains('maybePop(')));
  });

  test('horizontal browser overscroll is disabled where supported', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('overscroll-behavior-x: none;'));
  });
}
