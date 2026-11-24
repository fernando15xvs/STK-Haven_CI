import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rest timer displays seconds and links native ongoing notification', () {
    final active = File('lib/features/workout/presentation/active_workout_page_content.dart').readAsStringSync();
    final notification = File('lib/platform/workout/mobile_workout_notification_service.dart').readAsStringSync();
    // The rest buttons now live in a compact, in-flow component.
    final rest = File(
      'lib/features/workout/presentation/widgets/workout_rest_controls.dart',
    ).readAsStringSync();
    expect(active, contains('WorkoutRestControls('));
    expect(active, contains('onAdd15: () => _addRestSeconds(15)'));
    expect(active, contains('onAdd30: () => _addRestSeconds(30)'));
    expect(active, contains('onCustomize: _askAdditionalRestSeconds'));
    expect(active, contains('.skipRest()'));
    expect(rest, contains("'workout_rest_countdown'"));
    expect(rest, contains("'rest_banner'"));
    for (final caption in ["'+15 s'", "'+30 s'", "'Personalizar'", "'Omitir'"]) {
      expect(rest, contains(caption));
    }
    expect(notification, contains('usesChronometer: true'));
    expect(notification, contains('chronometerCountDown: true'));
    expect(notification, contains('silent: true'));
    expect(notification, contains('_queueRest('));
    expect(notification, contains('stk_rest_complete.wav'));
    // Android channels are immutable: v2 is required for the new
    // notification-event audio attributes, so tests must not pin v1.
    expect(notification, contains('workout_rest_stk_chime_v2_'));
    expect(notification, contains('AudioAttributesUsage.notificationEvent'));
    expect(notification, contains('ongoing: false'));
    expect(notification, contains('timeoutAfter: remainingMs,'));
  });

  test('native notification startup retries after a plugin failure', () {
    final notification = File(
      'lib/platform/workout/mobile_workout_notification_service.dart',
    ).readAsStringSync();
    final facade = File(
      '../../packages/core/lib/core/services/workout_notification_service.dart',
    ).readAsStringSync();
    final bootstrap = File(
      'lib/shared/bootstrap/mobile_app_bootstrap.dart',
    ).readAsStringSync();
    expect(notification, contains('_initialize().onError((error, stack)'));
    expect(notification, contains('_initialization = null;'));
    expect(notification, contains('Error.throwWithStackTrace('));
    expect(notification, contains('AudioAttributesUsage.notificationEvent'));
    expect(notification, contains("_restOngoingNotificationId = 998"));
    expect(notification, contains("_restTimerNotificationId = 999"));
    expect(facade, isNot(contains("package:flutter/")));
    expect(facade, isNot(contains('FlutterLocalNotificationsPlugin')));
    expect(facade, contains('installBackend(WorkoutNotificationBackend backend)'));
    expect(bootstrap, contains('WorkoutNotificationService.installBackend('));
    expect(bootstrap, contains('const MobileWorkoutNotificationBackend()'));
  });

  test('original rest tone is bundled for both native platforms', () {
    for (final path in [
      'ios/Runner/stk_rest_complete.wav',
      'android/app/src/main/res/raw/stk_rest_complete.wav',
    ]) {
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(16000));
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
    }
    final xcode = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(xcode, contains('stk_rest_complete.wav in Resources'));
    final native = File('android/app/src/main/kotlin/com/Fernando_S_ac/gym_tracker/MainActivity.kt').readAsStringSync();
    expect(native, contains('R.raw.stk_rest_complete'));
  });

  test('iOS live activity has fallbacks and a single WidgetBundle entrypoint', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final widget = File('ios/StkVerseWidget/StkVerseWidget.swift').readAsStringSync();
    final bridge = File('ios/Runner/StkRestLiveActivityBridge.swift').readAsStringSync();
    expect(plist, contains('NSSupportsLiveActivities'));
    expect(widget, contains('ActivityConfiguration(for: StkRestActivityAttributes.self)'));
    expect(widget, contains('struct StkHavenWidgetBundle: WidgetBundle'));
    expect(bridge, contains('ActivityAuthorizationInfo().areActivitiesEnabled'));
    expect(bridge, contains('activity.end(dismissalPolicy: .immediate)'));
  });

  test('summary is short by default but retains secondary insights', () {
    final summary = File('lib/features/workout/presentation/workout_summary_page.dart').readAsStringSync();
    expect(summary, contains('bool _showFullAnalysis = false'));
    expect(summary, contains("Ver análisis completo"));
    expect(summary, contains('cautionExerciseIds'));
    final active = File('lib/features/workout/presentation/active_workout_page_content.dart').readAsStringSync();
    expect(active, contains("case 'supersets':"));
    expect(active, contains("case 'plates':"));
    // Motivation's library entry is in the global + menu, not here.
    expect(active, isNot(contains("case 'motivation':")));
    expect(active, isNot(contains("value: 'motivation'")));
    expect(active, contains('showLauncherWhenEmpty: false'));
  });
}
