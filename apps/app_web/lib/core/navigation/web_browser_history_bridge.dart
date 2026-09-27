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
  final List<PageRoute<dynamic>> _pageRoutes = <PageRoute<dynamic>>[];

  void attach(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _backHandler = _handleBrowserBack.toJS;
    _stkSetFlutterBackHandler(_backHandler!);
    _stkHistoryInitialize();
  }

  void _handleBrowserBack() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || _pageRoutes.length <= 1) {
      return;
    }

    final route = _pageRoutes.last;
    switch (route.popDisposition) {
      case RoutePopDisposition.pop:
        // Safari already owns the visual edge-swipe transition. Removing the
        // Flutter route immediately avoids running a second reverse page
        // animation on top of Safari's snapshot, which was the source of the
        // duplicated/overlapping screens on iPhone.
        navigator.removeRoute(route);
        return;
      case RoutePopDisposition.doNotPop:
      case RoutePopDisposition.bubble:
        // The browser already moved one managed history entry. Put a marker
        // back when the route refuses to leave so browser and Flutter stay in
        // sync.
        _stkHistoryRoutePushed();
        return;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is! PageRoute<dynamic>) return;

    _pageRoutes.add(route);
    if (previousRoute != null) {
      _stkHistoryRoutePushed();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is! PageRoute<dynamic>) return;

    _pageRoutes.remove(route);
    if (previousRoute != null) {
      _stkHistoryRoutePopped();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute<dynamic>) {
      _pageRoutes.remove(route);
    }
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    final oldIndex =
        oldRoute == null ? -1 : _pageRoutes.indexOf(oldRoute);
    if (oldIndex >= 0) {
      if (newRoute is PageRoute<dynamic>) {
        _pageRoutes[oldIndex] = newRoute;
      } else {
        _pageRoutes.removeAt(oldIndex);
      }
    } else if (newRoute is PageRoute<dynamic>) {
      _pageRoutes.add(newRoute);
    }
  }
}
