import 'dart:async';

import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/features/workout/application/workout_native_services_port.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// iOS/Android implementation of the Core workout-native-effects port.
///
/// Uses the established OS notification queue, rest-expiry alarm and iOS Live
/// Activity. No session timestamps, rest policy or user data are owned here.
class MobileWorkoutNativeServices implements WorkoutNativeServices {
  const MobileWorkoutNativeServices();

  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endsAt, {
    String? workoutSessionId,
  }) => WorkoutNotificationService.scheduleRestTimerNotification(
    endsAt,
    workoutSessionId: workoutSessionId,
  );

  @override
  Future<void> cancelRestTimerNotification() =>
      WorkoutNotificationService.cancelRestTimerNotification();

  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt,
    required String workoutName,
  }) => WorkoutNotificationService.scheduleUnfinishedWorkoutReminder(
    lastActivityAt: lastActivityAt,
    workoutName: workoutName,
  );

  @override
  Future<void> cancelUnfinishedWorkoutReminders() =>
      WorkoutNotificationService.cancelUnfinishedWorkoutReminders();

  @override
  void playRestCompletionCueIfForeground({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    // When suspended, the scheduled OS notification remains authoritative.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    // On a foreground completion, clear the OS timer to avoid a duplicate cue.
    // Do not await the notification queue before playing the native sound.
    unawaited(WorkoutNotificationService.cancelRestTimerNotification());

    if (soundEnabled) unawaited(_playStkRestTone());
    if (vibrationEnabled) unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _playStkRestTone() async {
    try {
      final played = await const MethodChannel('stk_haven/rest_tone')
          .invokeMethod<bool>('play');
      if (played == true) return;
    } catch (_) {
      // Channel can be absent on an older/native test build.
    }
    // Deliberately no SystemSound.alert fallback: it may seize media focus
    // and pause third-party music such as YouTube Music.
  }
}
