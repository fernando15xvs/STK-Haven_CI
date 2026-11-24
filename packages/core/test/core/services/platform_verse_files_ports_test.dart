import 'package:core/core/services/backup_file_service.dart';
import 'package:core/core/services/daily_verse_settings_service.dart';
import 'package:core/features/faith/services/verse_background_service.dart';
import 'package:core/features/faith/services/verse_widget_sync.dart';
import 'package:core/features/profile/application/data_export_service.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:test/test.dart';

class _WidgetSpy implements VerseWidgetBackend {
  Map<String, String>? snapshot;
  int cleared = 0;
  @override
  bool get isSupportedPlatform => true;
  @override
  Future<void> publish(Map<String, String> value) async { snapshot = value; }
  @override
  Future<Map<String, bool>?> diagnostics() async => {'installed': true};
  @override
  Future<void> clear() async { cleared++; }
}

class _BackgroundSpy implements VerseBackgroundBackend {
  int? hour;
  int? minute;
  int initialized = 0;
  int cancelled = 0;
  @override
  Future<void> initialize() async { initialized++; }
  @override
  Future<void> scheduleDailyVerse(int h, int m) async { hour = h; minute = m; }
  @override
  Future<void> cancelDailyVerse() async { cancelled++; }
}

class _DailySpy implements DailyVerseSettingsBackend {
  bool? enabled;
  @override
  Future<bool> configure(bool value) async { enabled = value; return value; }
}

class _BackupSpy implements BackupFileBackend {
  String? json;
  @override
  Future<void> exportFile(String value) async { json = value; }
  @override
  Future<String?> pickBackupFile() async => '{"verified":true}';
}

class _ExportSpy implements DataExportBackend {
  List<WorkoutSession>? sessions;
  @override
  Future<void> exportWorkoutsToCSV(List<WorkoutSession> value) async {
    sessions = value;
  }
}

void main() {
  setUp(() {
    VerseWidgetSync.installBackend(null);
    VerseBackgroundService.installBackend(null);
    DailyVerseSettingsService.installBackend(null);
    BackupFileService.installBackend(null);
    DataExportService.installBackend(null);
  });

  tearDown(() {
    VerseWidgetSync.installBackend(null);
    VerseBackgroundService.installBackend(null);
    DailyVerseSettingsService.installBackend(null);
    BackupFileService.installBackend(null);
    DataExportService.installBackend(null);
  });

  test('uninstalled ports do not use OS or pretend user granted permission', () async {
    expect(VerseWidgetSync.isSupportedPlatform, false);
    await VerseWidgetSync.publish(
      text: 'Salmos', reference: 'Salmos 23:1', date: DateTime(2026),
    );
    expect(await VerseWidgetSync.diagnostics(), null);
    await VerseWidgetSync.clear();
    await VerseBackgroundService.initialize();
    await VerseBackgroundService.scheduleDailyVerse(8, 0);
    await VerseBackgroundService.cancelDailyVerse();
    expect(await configureDailyVerseNotifications(true), false);
    expect(await BackupFileService().pickBackupFile(), null);
    await expectLater(BackupFileService().exportFile('{}'), throwsStateError);
    await expectLater(DataExportService().exportWorkoutsToCSV([]), throwsStateError);
  });

  test('verse snapshots preserve trimmed/capped text and local date', () async {
    final spy = _WidgetSpy();
    VerseWidgetSync.installBackend(spy);
    await VerseWidgetSync.publish(
      text: '  ' + ('a' * 1500) + '  ',
      reference: 'b' * 150,
      date: DateTime(2026, 11, 24),
    );
    expect(spy.snapshot!['text']!.length, 1200);
    expect(spy.snapshot!['reference']!.length, 120);
    expect(spy.snapshot!['date'], '2026-11-24');
    await VerseWidgetSync.clear();
    expect(spy.cleared, 1);
    expect((await VerseWidgetSync.diagnostics())!['installed'], true);
    spy.snapshot = null;
    await VerseWidgetSync.publish(
      text: '   ', reference: 'Juan', date: DateTime(2026),
    );
    expect(spy.snapshot, null);
  });

  test('background scheduler preserves exact local hour, minute and cancellation', () async {
    final spy = _BackgroundSpy();
    VerseBackgroundService.installBackend(spy);
    await VerseBackgroundService.initialize();
    await VerseBackgroundService.scheduleDailyVerse(8, 30);
    await VerseBackgroundService.cancelDailyVerse();
    expect(spy.initialized, 1);
    expect((spy.hour, spy.minute, spy.cancelled), (8, 30, 1));
    expect(dailyVerseTask, 'dailyVerseTask');
  });

  test('settings, import and exports use original values without mutating data', () async {
    final settings = _DailySpy();
    final backup = _BackupSpy();
    final export = _ExportSpy();
    DailyVerseSettingsService.installBackend(settings);
    BackupFileService.installBackend(backup);
    DataExportService.installBackend(export);
    expect(await configureDailyVerseNotifications(true), true);
    expect(settings.enabled, true);
    await BackupFileService().exportFile('{"source":"device"}');
    expect(backup.json, '{"source":"device"}');
    expect(await BackupFileService().pickBackupFile(), '{"verified":true}');
    final sessions = <WorkoutSession>[];
    await DataExportService().exportWorkoutsToCSV(sessions);
    expect(identical(export.sessions, sessions), true);
  });
}
