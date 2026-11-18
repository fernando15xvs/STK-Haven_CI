import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cross-platform source contracts. Actual external-music focus and native
/// alarms still require real Android / iPhone device QA.
void main() {
  final root = Directory.current.path;
  String project(String relativePath) =>
      File('$root/$relativePath').readAsStringSync();
  String shared(String relativePath) =>
      File('$root/../../packages/core/$relativePath').readAsStringSync();

  test('Android rest notification expires even if Flutter is suspended', () {
    final service = shared(
      'lib/core/services/workout_notification_service.dart',
    );
    expect(service, contains("MethodChannel('stk_haven/rest_expiry')"));
    expect(service, contains('ongoing: false'));
    expect(service, contains('autoCancel: true'));
    expect(service, contains('timeoutAfter: remainingMs,'));
    expect(service, contains('chronometerCountDown: true'));
    expect(service, contains('await _setAndroidRestExpiry(endTime);'));
    expect(service, contains('await _setAndroidRestExpiry(null);'));
    expect(service, contains('_restOngoingNotificationId = 998'));
    expect(service, contains('_restTimerNotificationId = 999'));
    expect(service, contains('generation != _restGeneration'));
    final cancelNative = service.indexOf(
      'await _setAndroidRestExpiry(null);',
      service.indexOf('scheduleRestTimerNotification('),
    );
    final requestPermission = service.indexOf(
      'if (!await requestNotificationPermission()) return;',
      service.indexOf('scheduleRestTimerNotification('),
    );
    expect(cancelNative, lessThan(requestPermission),
        reason: 'Previously pinned countdown must be canceled even '
            'when notification permissions change.');
  });

  test('native expiry receiver cancels only the old 998 countdown', () {
    final receiver = project(
      'android/app/src/main/kotlin/com/Fernando_S_ac/gym_tracker/'
      'StkRestCountdownExpiryReceiver.kt',
    );
    final main = project(
      'android/app/src/main/kotlin/com/Fernando_S_ac/gym_tracker/'
      'MainActivity.kt',
    );
    final manifest = project('android/app/src/main/AndroidManifest.xml');
    expect(receiver, contains('AlarmManager.RTC_WAKEUP'));
    expect(receiver, contains('alarms.setExactAndAllowWhileIdle('));
    expect(receiver, contains('alarms.setAndAllowWhileIdle('));
    expect(receiver, contains('manager.cancel(ONGOING_REST_NOTIFICATION_ID)'));
    expect(receiver, contains('scheduled != current'));
    expect(receiver, contains('System.currentTimeMillis() < scheduled'));
    expect(receiver, contains('private const val ONGOING_REST_NOTIFICATION_ID = 998'));
    expect(receiver, isNot(contains('manager.cancel(999)')));
    expect(main, contains('"stk_haven/rest_expiry"'));
    expect(main, contains('StkRestCountdownExpiryReceiver.schedule(this, deadline)'));
    expect(main, contains('StkRestCountdownExpiryReceiver.cancel(this)'));
    expect(manifest, contains('android:name=".StkRestCountdownExpiryReceiver"'));
    expect(manifest, contains('android:exported="false"'));
  });

  test('expiry on restore and Skip/Finish also clear all native timers', () {
    final provider = shared(
      'lib/features/workout/application/active_workout_provider.dart',
    );
    expect(provider, contains('unawaited(WorkoutNotificationService.'
        'cancelRestTimerNotification());'));
    expect(provider, contains('WorkoutNotificationService.'
        'cancelRestTimerNotification();'));
    expect(provider, contains('_clearRestInDraft(draft);'));
    expect(provider, contains('session: _rebuildSession('));
    expect(provider, contains('restTimerSeconds: 0'));
    expect(provider, contains('isResting: false'));
    expect(provider, contains('if (remaining > 0)'));
    expect(provider, contains('timer.cancel();'));
  });

  test('Android chime does not request music audio focus', () {
    final main = project(
      'android/app/src/main/kotlin/com/Fernando_S_ac/gym_tracker/'
      'MainActivity.kt',
    );
    final service = shared(
      'lib/core/services/workout_notification_service.dart',
    );
    expect(main, contains('AudioAttributes.USAGE_ASSISTANCE_SONIFICATION'));
    expect(main, contains('AudioAttributes.CONTENT_TYPE_SONIFICATION'));
    expect(main, isNot(contains('MediaPlayer.create(')));
    expect(main, isNot(contains('requestAudioFocus(')));
    expect(main, isNot(contains('AudioAttributes.USAGE_MEDIA')));
    expect(service, contains('AudioAttributesUsage.notificationEvent'));
    expect(service, contains('importance: Importance.defaultImportance'));
    expect(service, contains('priority: Priority.defaultPriority'));
    expect(service, contains('workout_rest_stk_chime_v2_'));
    // The background finish alert is distinct from the foreground cue.
    expect(service, contains("body: 'Es hora de la siguiente serie. ¡Vamos!'"));
  });

  test('iOS Live Activity does not show an endless 0:00 on resume', () {
    final bridge = project('ios/Runner/StkRestLiveActivityBridge.swift');
    final delegate = project('ios/Runner/AppDelegate.swift');
    final widget = project('ios/StkVerseWidget/StkVerseWidget.swift');
    expect(bridge, contains('static func endExpired() async'));
    expect(bridge, contains('activity.content.state.endTime <= now'));
    expect(bridge, contains('activity.end(dismissalPolicy: .immediate)'));
    expect(delegate, contains('applicationDidBecomeActive'));
    expect(delegate, contains('StkRestLiveActivityBridge.endExpired()'));
    expect(widget, contains('if context.isStale'));
    expect(widget, contains('Descanso finalizado'));
    expect(widget, contains('Image(systemName: "checkmark.circle.fill")'));
    // A stale date is a UI hint, not an OS-guaranteed background dismissal.
    expect(bridge, contains('staleDate: endTime'));
  });

  test('iOS foreground chime is System Sound, not AVAudioPlayer media', () {
    final delegate = project('ios/Runner/AppDelegate.swift');
    final provider = shared(
      'lib/features/workout/application/active_workout_provider.dart',
    );
    expect(delegate, contains('import AudioToolbox'));
    expect(delegate, contains('AudioServicesCreateSystemSoundID('));
    expect(delegate, contains('AudioServicesPlaySystemSound('));
    expect(delegate, isNot(contains('AVAudioPlayer(')));
    expect(delegate, isNot(contains('setCategory(.playback')));
    expect(provider, isNot(contains('SystemSound.play(SystemSoundType.alert)')));
    expect(provider, contains("MethodChannel('stk_haven/rest_tone')"));
    expect(provider, contains('settings.timerSoundEnabled'));
    expect(provider, contains('settings.vibrationEnabled'));
  });
}
