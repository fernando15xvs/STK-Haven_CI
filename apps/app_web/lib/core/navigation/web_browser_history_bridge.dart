import 'dart:js_interop';

import 'package:flutter/material.dart';

@JS('stkHistoryInitialize')
external void _stkHistoryInitialize();

/// Web navigation intentionally does not mirror Flutter routes into browser
/// history.
///
/// Internal back navigation is handled only by the arrows/buttons rendered by
/// Flutter. Safari/iOS browser Back (including the left-edge swipe) is trapped
/// by the small history guard installed from index.html and never pops a
/// Flutter route.
class WebBrowserHistoryBridge extends NavigatorObserver {
  void attach(GlobalKey<NavigatorState> navigatorKey) {
    _stkHistoryInitialize();
  }
}
