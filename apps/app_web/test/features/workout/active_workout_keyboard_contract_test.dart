import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile web repairs the viewport after the system keyboard closes', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('interactive-widget=resizes-content'));
    expect(html, contains('const stkVisualViewport = window.visualViewport;'));
    expect(
      html,
      contains("stkVisualViewport.addEventListener(\n        'resize'"),
    );
    expect(html, contains('window.requestAnimationFrame(() => {'));
    expect(html, contains('document.documentElement.scrollTop = 0;'));
    expect(html, contains("window.dispatchEvent(new Event('resize'));"));
    expect(html, contains("document.addEventListener(\n      'focusout'"));
    expect(html, contains('stkForceFlutterViewportSync, 420'));
  });

  test('web set input coalesces drafts and flushes when editing finishes', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_web_content.dart',
    ).readAsStringSync();

    expect(source, contains('Timer? _updateDebounce;'));
    expect(source, contains('Duration(milliseconds: 350)'));
    expect(source, contains('onChanged: (_) => _scheduleUpdate()'));
    expect(source, contains('onSubmitted: (_) => _finishEditing()'));
    expect(source, contains('onTapOutside: (_) => _finishEditing()'));
    expect(source, contains('textInputAction: TextInputAction.done'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
  });

  test('native workout input flushes its debounce on Done or outside tap', () {
    final source = File(
      '../app_mobile/lib/features/workout/presentation/'
      'active_workout_page_content.dart',
    ).readAsStringSync();

    expect(source, contains('onEditingComplete: _flushDebounce'));
    expect(source, contains('textInputAction: TextInputAction.done'));
    expect(source, contains('widget.onEditingComplete?.call();'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
  });
}
