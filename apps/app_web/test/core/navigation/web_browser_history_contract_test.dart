import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('managed browser Back is consumed exactly once', () {
    final html = File('web/index.html').readAsStringSync();
    final listenerStart =
        html.indexOf("window.addEventListener('popstate', (event) => {");
    final listenerEnd = html.indexOf(
      '    function stkUrlBase64ToUint8Array',
      listenerStart,
    );

    expect(listenerStart, greaterThanOrEqualTo(0));
    expect(listenerEnd, greaterThan(listenerStart));

    final listener = html.substring(listenerStart, listenerEnd);
    expect(listener, contains('const managed ='));
    expect(listener, contains('event.stopImmediatePropagation();'));
    expect(listener, contains('targetDepth < stkHistoryDepth'));
    expect(listener, contains('stkFlutterBackHandler();'));
    expect(listener, isNot(contains('stkSuppressNextPop')));
  });

  test('in-app Flutter Back never traverses to another document entry', () {
    final html = File('web/index.html').readAsStringSync();
    final popStart = html.indexOf('window.stkHistoryRoutePopped = () => {');
    final popEnd = html.indexOf(
      "window.addEventListener('popstate'",
      popStart,
    );

    expect(popStart, greaterThanOrEqualTo(0));
    expect(popEnd, greaterThan(popStart));

    final popHandler = html.substring(popStart, popEnd);
    expect(popHandler, isNot(contains('history.back()')));
    expect(popHandler, isNot(contains('history.go(')));
    expect(popHandler, contains('history.replaceState('));
  });

  test('Safari browser Back removes the Flutter page without reverse animation',
      () {
    final bridge = File(
      'lib/core/navigation/web_browser_history_bridge.dart',
    ).readAsStringSync();

    expect(bridge, contains('navigator.removeRoute(route);'));
    expect(bridge, isNot(contains('navigator.maybePop()')));
    expect(bridge, contains('RoutePopDisposition.doNotPop'));
  });
}
