import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/presentation/verse_notification_settings_page.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(dailyVerseNotifications: false);
  @override
  Future<void> setDailyVerseNotifications(bool enable) async {
    state = state.copyWith(dailyVerseNotifications: enable);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('stk_haven/timezone');
  setUp(() {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(timezone, (_) async => 'America/Lima');
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'checkPermissions')
        return {'isEnabled': true, 'isAlertEnabled': true};
      if (call.method == 'pendingNotificationRequests') return [];
      throw StateError('Unexpected scheduling: ${call.method}');
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });
  testWidgets(
    'compact phone displays custom hours and interval controls without enabling notifications',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: const MaterialApp(home: VerseNotificationSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Añadir hora'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.text('A horas específicas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cada cierto tiempo').last);
      await tester.pumpAndSettle();
      expect(find.text('Frecuencia'), findsOneWidget);
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
