import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('stk_haven/timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final pending = <int, Map<String, Object?>>{};
  final scheduled = <Map<dynamic, dynamic>>[];
  var permission = true;
  var failSchedule = false;

  setUp(() {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    pending.clear();
    scheduled.clear();
    permission = true;
    failSchedule = false;
    messenger.setMockMethodCallHandler(timezone, (_) async => 'America/Lima');
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestPermissions':
          return permission;
        case 'checkPermissions':
          return {'isEnabled': permission, 'isAlertEnabled': permission};
        case 'pendingNotificationRequests':
          return pending.values.toList();
        case 'cancel':
          pending.remove(call.arguments as int);
          return null;
        case 'zonedSchedule':
          final args = Map<dynamic, dynamic>.from(call.arguments as Map);
          if (failSchedule) throw PlatformException(code: 'schedule_failed');
          scheduled.add(args);
          pending[args['id'] as int] = {
            'id': args['id'],
            'title': args['title'],
            'body': args['body'],
            'payload': null,
          };
          return null;
      }
      throw StateError('Unexpected native call: ${call.method}');
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  final measurements = [
    BodyMeasurement(id: 'latest', date: DateTime(2099, 1, 31), leftArmCm: 30),
  ];
  test('schedules calendar date and only replaces own notification', () async {
    pending[1310] = {'id': 1310};
    await MeasurementReminderService.configure(
      const MeasurementReminderSettings(
        enabled: true,
        months: 1,
        hour: 18,
        minute: 30,
      ),
      measurements,
    );
    expect(pending.keys.toSet(), {1310, 1601});
    expect(
      scheduled.single['scheduledDateTime'],
      contains('2099-02-28T18:30:00'),
    );
    expect(scheduled.single['timeZoneName'], 'America/Lima');
    expect((await MeasurementReminderService.read()).enabled, true);
    await MeasurementReminderService.configure(
      const MeasurementReminderSettings(),
      measurements,
    );
    expect(pending.keys.toSet(), {1310});
    expect((await MeasurementReminderService.read()).enabled, false);
  });
  test('permission denial does not save enabled consent', () async {
    permission = false;
    await expectLater(
      MeasurementReminderService.configure(
        const MeasurementReminderSettings(enabled: true),
        measurements,
      ),
      throwsStateError,
    );
    expect(scheduled, isEmpty);
    expect((await MeasurementReminderService.read()).enabled, false);
  });
  test(
    'full iOS queue preserves other notifications and existing configuration',
    () async {
      for (var i = 0; i < 60; i++) {
        pending[i] = {'id': i};
      }
      await expectLater(
        MeasurementReminderService.configure(
          const MeasurementReminderSettings(enabled: true),
          measurements,
        ),
        throwsStateError,
      );
      expect(pending.length, 60);
      expect((await MeasurementReminderService.read()).enabled, false);
    },
  );
  test(
    'new measurement shifts the reminder; deleting all cancels it',
    () async {
      await MeasurementReminderService.configure(
        const MeasurementReminderSettings(enabled: true, months: 3),
        measurements,
      );
      await MeasurementReminderService.synchronize([
        BodyMeasurement(id: 'new', date: DateTime(2099, 2, 10)),
      ]);
      expect(
        scheduled.last['scheduledDateTime'],
        contains('2099-05-10T09:00:00'),
      );
      await MeasurementReminderService.synchronize([]);
      expect(pending, isEmpty);
    },
  );
  test(
    'overdue reminder is scheduled once, not resent on every startup',
    () async {
      final old = [BodyMeasurement(id: 'old', date: DateTime(2020, 1))];
      await MeasurementReminderService.configure(
        const MeasurementReminderSettings(enabled: true),
        old,
      );
      await MeasurementReminderService.synchronize(old);
      expect(scheduled.length, 1);
    },
  );
  test(
    'native scheduling failure is reported without enabling preference',
    () async {
      failSchedule = true;
      await expectLater(
        MeasurementReminderService.configure(
          const MeasurementReminderSettings(enabled: true),
          measurements,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect((await MeasurementReminderService.read()).enabled, false);
    },
  );
}
