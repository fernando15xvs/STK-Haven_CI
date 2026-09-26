import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';

@JS('stkHistoryInitialize')
external void _stkHistoryInitialize();

@JS('stkHistoryRoutePushed')
external void _stkHistoryRoutePushed();

@JS('stkHistoryRoutePopped')
external void _stkHistoryRoutePopped();

@JS('stkSetFlutterBackHandler')
external void _stkSetFlutterBackHandler(JSFunction handler);

class WebBrowserHistoryBridge extends NavigatorObserver {
  GlobalKey<NavigatorState>? _navigatorKey;
  JSExportedDartFunction? _backHandler;
  bool _browserPopInFlight = false;

  void attach(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _backHandler = _handleBrowserBack.toJS;
    _stkSetFlutterBackHandler(_backHandler!);
    _stkHistoryInitialize();
  }

  void _handleBrowserBack() {
    unawaited(_popFromBrowser());
  }

  Future<void> _popFromBrowser() async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }

    _browserPopInFlight = true;
    final didPop = await navigator.maybePop();
    if (!didPop) {
      _browserPopInFlight = false;
      // The browser already moved one history entry. Restore the marker when
      // the current Flutter route refuses to pop (for example, a guarded form).
      _stkHistoryRoutePushed();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null && route is PageRoute<dynamic>) {
      _stkHistoryRoutePushed();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is! PageRoute<dynamic> || previousRoute == null) return;

    if (_browserPopInFlight) {
      _browserPopInFlight = false;
      return;
    }
    _stkHistoryRoutePopped();
  }
}
