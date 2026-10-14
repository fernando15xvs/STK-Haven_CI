import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/domain/verse_notification_schedule.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('stk_haven/timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final pending = <int, Map<String, Object?>>{};
  final scheduled = <Map<dynamic, dynamic>>[];
  var permission = true;
  var failSecond = false;
  const content = [
    Verse(book: 'Salmos', chapter: 23, verse: 1, text: 'Texto uno de prueba'),
    Verse(book: 'Juan', chapter: 14, verse: 27, text: 'Texto dos de prueba'),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    pending.clear();
    scheduled.clear();
    permission = true;
    failSecond = false;
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
          pending.remove((call.arguments as Map)['id']);
          return null;
        case 'zonedSchedule':
          final args = Map<dynamic, dynamic>.from(call.arguments as Map);
          if (failSecond && scheduled.isNotEmpty)
            throw PlatformException(code: 'schedule_failed');
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

  test(
    'registers distinct verses at chosen local times, replaces legacy only',
    () async {
      pending[1301] = {'id': 1301};
      pending[999] = {'id': 999};
      await VerseNotificationService.schedule(
        const VerseNotificationSchedule(times: [480, 1200]),
        verses: content,
      );
      expect(scheduled.map((s) => s['body']), [
        'Texto uno de prueba',
        'Texto dos de prueba',
      ]);
      expect(scheduled.map((s) => s['timeZoneName']).toSet(), {'America/Lima'});
      expect(scheduled.first['scheduledDate'].toString(), contains('08:00:00'));
      expect(scheduled.last['scheduledDate'].toString(), contains('20:00:00'));
      expect(pending.keys.toSet(), {999, 1310, 1311});
      expect(await VerseNotificationService.pendingDailyReminderCount(), 2);
      final now = tz.TZDateTime.now(tz.local);
      for (final slot in scheduled) {
        final local = DateTime.parse(slot['scheduledDate'] as String);
        expect(
          tz.TZDateTime(
            tz.local,
            local.year,
            local.month,
            local.day,
            local.hour,
            local.minute,
          ).isAfter(now),
          true,
        );
      }
    },
  );
  test(
    'denied permissions preserve existing schedule and report failure',
    () async {
      permission = false;
      pending[1301] = {'id': 1301};
      await expectLater(
        VerseNotificationService.schedule(
          const VerseNotificationSchedule(),
          verses: content.take(1).toList(),
        ),
        throwsStateError,
      );
      expect(pending.keys, [1301]);
      expect(scheduled, isEmpty);
    },
  );
  test(
    'rejects exhausted iOS capacity before replacing notifications',
    () async {
      for (var i = 0; i < 59; i++) {
        pending[10000 + i] = {'id': 10000 + i};
      }
      pending[1301] = {'id': 1301};
      await expectLater(
        VerseNotificationService.schedule(
          const VerseNotificationSchedule(times: [480, 1200]),
          verses: content,
        ),
        throwsStateError,
      );
      expect(pending.length, 60);
      expect(scheduled, isEmpty);
    },
  );
  test(
    'empty Bible cannot turn a working reminder into a false success',
    () async {
      pending[1301] = {'id': 1301};
      await expectLater(
        VerseNotificationService.schedule(
          const VerseNotificationSchedule(),
          verses: [],
        ),
        throwsStateError,
      );
      expect(pending.keys, [1301]);
    },
  );
  test(
    'partial native failure cleans owned slots and leaves other services intact',
    () async {
      pending[999] = {'id': 999};
      failSecond = true;
      await expectLater(
        VerseNotificationService.schedule(
          const VerseNotificationSchedule(times: [480, 1200]),
          verses: content,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(pending.keys, [999]);
    },
  );
  test('preview is a one-off and does not replace recurring slots', () async {
    pending[1310] = {'id': 1310};
    await VerseNotificationService.schedulePreview();
    expect(pending.keys.toSet(), {1302, 1310});
    expect(scheduled.single['matchDateTimeComponents'], isNull);
  });
  test(
    'disable cancels all owned slots including the test, never other families',
    () async {
      for (final id in [1301, 1302, 1310, 1357, 42910]) {
        pending[id] = {'id': id};
      }
      await VerseNotificationService.cancelDailyReminder();
      expect(pending.keys, [42910]);
    },
  );
  test(
    'personal reminders cannot evict registered verse notifications on iOS',
    () async {
      for (var i = 0; i < 13; i++) {
        pending[1310 + i] = {'id': 1310 + i};
      }
      final personal = PersonalReminderSettings(
        enabled: true,
        intervalMinutes: 30,
        messages: [
          const PersonalReminderMessage(title: 'Prueba', message: 'Mensaje'),
        ],
      );
      await expectLater(
        PersonalMotivationalReminderService.synchronize(personal),
        throwsStateError,
      );
      expect(pending.length, 13);
      expect(scheduled, isEmpty);
    },
  );
  test(
    'background restoration cannot re-enable a revoked preference',
    () async {
      await VerseNotificationService.schedule(
        const VerseNotificationSchedule(),
        verses: content.take(1).toList(),
        requireSavedConsent: true,
      );
      expect(scheduled, isEmpty);
    },
  );
}
