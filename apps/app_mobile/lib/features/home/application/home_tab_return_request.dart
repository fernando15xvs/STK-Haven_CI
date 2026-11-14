import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot requests from nested routes to select the retained Home tab.
class HomeTabReturnRequest extends Notifier<int> {
  @override
  int build() => 0;

  void requestHome() => state += 1;
}

final homeTabReturnRequestProvider =
    NotifierProvider<HomeTabReturnRequest, int>(HomeTabReturnRequest.new);
