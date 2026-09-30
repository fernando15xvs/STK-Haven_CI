import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile web repairs the viewport after the system keyboard closes', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, isNot(contains('interactive-widget=resizes-content')));
    expect(html, contains('const stkVisualViewport = window.visualViewport;'));
    expect(
      html,
      contains("document.addEventListener(\n      'focusin'"),
    );
    expect(html, contains('stkVisualViewport.removeEventListener('));
    expect(html, contains('html.stk-keyboard-viewport-lock flutter-view'));
    expect(html, contains("'--stk-full-viewport-height'"));
    expect(html, contains("'stk-keyboard-viewport-lock'"));
    expect(html, contains('function stkLockFullViewport()'));
    expect(html, contains('function stkUnlockFullViewport()'));
    expect(
      html,
      isNot(contains(r'document.body.style.height = `${height}px`')),
    );
    expect(
      html,
      isNot(contains("document.body.style.background = 'transparent'")),
    );
    expect(html, contains("document.body.style.background = '#090A0C'"));
    expect(html, contains('let stkStableViewportHeight = Math.max('));
    expect(html, contains('window.requestAnimationFrame(() => {'));
    expect(html, contains('document.documentElement.scrollTop = 0;'));
    expect(html, contains("window.dispatchEvent(new Event('resize'));"));
    expect(html, contains("document.addEventListener(\n      'focusout'"));
    expect(html, contains('[80, 180, 360, 600]'));
    expect(html, contains('window.stkRecoverKeyboardViewport'));
  });

  test('web set input coalesces drafts and flushes when editing finishes', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_web_content.dart',
    ).readAsStringSync();

    expect(source, contains('Timer? _updateDebounce;'));
    expect(source, contains('Duration(milliseconds: 350)'));
    expect(source, contains('onChanged: (_) => _scheduleUpdate()'));
    expect(source, contains('onEditingComplete: _finishEditing'));
    expect(source, contains('onTapOutside: (_) => _finishEditing()'));
    expect(source, contains('textInputAction: TextInputAction.done'));
    expect(source, contains('recoverKeyboardViewport();'));
    final webBridge = File(
      'lib/features/workout/presentation/keyboard_viewport_bridge_web.dart',
    ).readAsStringSync();
    expect(webBridge, contains("@JS('stkRecoverKeyboardViewport')"));
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
