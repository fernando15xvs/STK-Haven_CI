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
    expect(
      RegExp(r'event\.stopImmediatePropagation\(\);')
          .allMatches(listener)
          .length,
      2,
    );
    expect(listener, contains('stkSuppressNextPop = false;'));
    expect(listener, contains('stkFlutterBackHandler();'));
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
}
