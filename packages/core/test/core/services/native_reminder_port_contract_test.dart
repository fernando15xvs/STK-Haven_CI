import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/domain/verse_notification_schedule.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';
import 'package:test/test.dart';

class _VerseSpy implements VerseNotificationBackend {
  final events = <String>[];
  VerseNotificationSchedule? scheduleValue;
  bool? consentCheck;
  List<Verse>? passedVerses;

  @override
  Future<void> initialize() async { events.add('init'); }
  @override
  Future<bool> requestPermissions() async {
    events.add('request');
    return true;
  }
  @override
  Future<bool> permissionEnabled() async {
    events.add('enabled');
    return true;
  }
  @override
  Future<void> scheduleDailyReminder() async {
    events.add('daily');
  }
  @override
  Future<void> schedule(VerseNotificationSchedule settings, {
    List<Verse>? verses,
    bool requireSavedConsent = false,
  }) async {
    scheduleValue = settings;
    passedVerses = verses;
    consentCheck = requireSavedConsent;
    events.add('schedule');
  }
  @override
  Future<int> pendingDailyReminderCount() async {
    events.add('count');
    return 2;
  }
  @override
  Future<void> cancelDailyReminder() async { events.add('cancel'); }
  @override
  Future<void> schedulePreview() async { events.add('preview'); }
  @override
  Future<void> showNotification({
    required String title, required String body,
  }) async { events.add('show:$title:$body'); }
}

class _PersonalSpy implements PersonalMotivationalReminderBackend {
  PersonalReminderSettings? settings;
  PersonalReminderMessage? preview;
  final events = <String>[];
  @override
  Future<void> initialize() async { events.add('init'); }
  @override
  Future<bool> requestPermission() async {
    events.add('request');
    return true;
  }
  @override
  Future<int> pendingSlots() async {
    events.add('slots');
    return 17;
  }
  @override
  Future<void> cancel() async { events.add('cancel'); }
  @override
  Future<void> synchronize(PersonalReminderSettings settings) async {
    this.settings = settings;
    events.add('sync');
  }
  @override
  Future<void> showPreview(
    PersonalReminderSettings settings, PersonalReminderMessage item,
  ) async {
    this.settings = settings;
    preview = item;
    events.add('preview');
  }
}

class _MeasureSpy implements MeasurementReminderBackend {
  MeasurementReminderSettings? stored;
  List<BodyMeasurement>? measured;
  final events = <String>[];
  @override
  Future<MeasurementReminderSettings> read() async {
    events.add('read');
    return stored ?? const MeasurementReminderSettings();
  }
  @override
  Future<void> configure(
    MeasurementReminderSettings settings, List<BodyMeasurement> measurements,
  ) async {
    events.add('configure');
    stored = settings;
    measured = measurements;
  }
  @override
  Future<void> synchronize(List<BodyMeasurement> measurements) async {
    measured = measurements;
    events.add('sync');
  }
}

void main() {
  setUp(() {
    VerseNotificationService.installBackend(null);
    PersonalMotivationalReminderService.installBackend(null);
    MeasurementReminderService.installBackend(null);
  });
  tearDown(() {
    VerseNotificationService.installBackend(null);
    PersonalMotivationalReminderService.installBackend(null);
    MeasurementReminderService.installBackend(null);
  });

  test('Core without Mobile cannot assert OS permissions, pending alerts or consent', () async {
    expect(await VerseNotificationService.requestPermissions(), false);
    expect(await VerseNotificationService.permissionEnabled(), false);
    expect(await VerseNotificationService.pendingDailyReminderCount(), 0);
    expect(await PersonalMotivationalReminderService.requestPermission(), false);
    expect(await PersonalMotivationalReminderService.pendingSlots(), 0);
    expect((await MeasurementReminderService.read()).enabled, false);
    await VerseNotificationService.scheduleDailyReminder();
    await VerseNotificationService.schedule(const VerseNotificationSchedule());
    await VerseNotificationService.cancelDailyReminder();
    await PersonalMotivationalReminderService.cancel();
    await MeasurementReminderService.synchronize([]);
    await expectLater(
      MeasurementReminderService.configure(const MeasurementReminderSettings(enabled: true), []),
      throwsStateError,
    );
  });

  test('Verse contract retains legacy IDs, preview, consent, content and times', () async {
    final spy = _VerseSpy();
    VerseNotificationService.installBackend(spy);
    const schedule = VerseNotificationSchedule(times: [480, 1200]);
    const verses = [Verse(book: 'Salmos', chapter: 23, verse: 1, text: 'Verso')];
    await VerseNotificationService.initialize();
    expect(await VerseNotificationService.requestPermissions(), true);
    expect(await VerseNotificationService.permissionEnabled(), true);
    await VerseNotificationService.schedule(schedule, verses: verses, requireSavedConsent: true);
    await VerseNotificationService.scheduleDailyReminder();
    expect(await VerseNotificationService.pendingDailyReminderCount(), 2);
    await VerseNotificationService.schedulePreview();
    await VerseNotificationService.showNotification(title: 'Título', body: 'Cuerpo');
    await VerseNotificationService.cancelDailyReminder();
    expect(identical(spy.scheduleValue, schedule), true);
    expect(identical(spy.passedVerses, verses), true);
    expect(spy.consentCheck, true);
    expect(VerseNotificationService.legacyId, 1301);
    expect(VerseNotificationService.previewId, 1302);
    expect(VerseNotificationService.firstSlotId, 1310);
    expect(VerseNotificationService.ownsSlot(1310), true);
    expect(VerseNotificationService.ownsSlot(1358), false);
    expect(spy.events, ['init','request','enabled','schedule','daily','count','preview','show:Título:Cuerpo','cancel']);
  });

  test('Personal reminder contract preserves 48 slots and message identity', () async {
    final spy = _PersonalSpy();
    PersonalMotivationalReminderService.installBackend(spy);
    const msg = PersonalReminderMessage(title: 'Ánimo', message: 'Adelante');
    final settings = PersonalReminderSettings(
      messages: [msg], enabled: true, intervalMinutes: 60,
    );
    await PersonalMotivationalReminderService.initialize();
    expect(await PersonalMotivationalReminderService.requestPermission(), true);
    expect(await PersonalMotivationalReminderService.pendingSlots(), 17);
    await PersonalMotivationalReminderService.synchronize(settings);
    await PersonalMotivationalReminderService.showPreview(settings, msg);
    await PersonalMotivationalReminderService.cancel();
    expect(identical(spy.settings, settings), true);
    expect(identical(spy.preview, msg), true);
    expect(PersonalMotivationalReminderService.expectedSlots(settings), 24);
    expect(PersonalMotivationalReminderService.maxDailySlots, 48);
    expect(PersonalMotivationalReminderService.legacyNotificationId, 42901);
    expect(spy.events, ['init','request','slots','sync','preview','cancel']);
  });

  test('Measurement model stays in Core; native adapter receives identical values', () async {
    final spy = _MeasureSpy();
    MeasurementReminderService.installBackend(spy);
    const settings = MeasurementReminderSettings(enabled: true, months: 3);
    final list = [BodyMeasurement(id: 'one', date: DateTime(2026, 11, 20))];
    await MeasurementReminderService.configure(settings, list);
    expect(identical(await MeasurementReminderService.read(), settings), true);
    expect(identical(spy.measured, list), true);
    await MeasurementReminderService.synchronize(list);
    expect(MeasurementReminderService.notificationId, 1601);
    expect(spy.events, ['configure','read','sync']);
  });
}
