import 'dart:async';

import 'package:flutter/foundation.dart';

/// One-shot, wall-clock sleep timer. Does not modify workout/rest timers.
///
/// This is an in-process timer: iOS/Android can suspend the app in the
/// background, so exact off-screen timing must be verified on real devices.
class MotivationSleepTimer extends ChangeNotifier {
  MotivationSleepTimer({
    required this.onExpired,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final VoidCallback onExpired;
  final DateTime Function() _clock;
  Timer? _ticker;
  DateTime? _deadline;

  bool get active => _deadline != null;
  DateTime? get deadline => _deadline;

  Duration get remaining {
    final deadline = _deadline;
    if (deadline == null) return Duration.zero;
    final difference = deadline.difference(_clock());
    return difference.isNegative ? Duration.zero : difference;
  }

  void start(Duration duration) {
    if (duration <= Duration.zero) {
      cancel();
      return;
    }
    _ticker?.cancel();
    _deadline = _clock().add(duration);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => checkDeadline(),
    );
    notifyListeners();
  }

  /// Also called when the app resumes after possible OS suspension.
  void checkDeadline() {
    if (_deadline == null) return;
    if (!_clock().isBefore(_deadline!)) {
      cancel();
      onExpired();
    } else {
      notifyListeners();
    }
  }

  void cancel() {
    final wasActive = active;
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    if (wasActive) notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
