import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('local backup picker restores exactly the validated schema',(){
    final source=File(
      'lib/features/sync/presentation/backup_status_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('static Future<void> _restoreLocalBackup(');
    expect(start,greaterThanOrEqualTo(0));
    final restore=source.substring(start);
    expect(restore,contains('_backupService.validateBackup(jsonString)'));
    expect(restore,contains('schemaVersion: result.schemaVersion ??'));
    expect(restore,contains('BackupService.currentBackupSchemaVersion'));
    expect(restore,contains('await _backupService.restoreBackup('));
    expect(restore,contains("parsed['routines'] as List?"));
    expect(restore,contains("parsed['workouts'] as List?"));
    expect(restore,contains("parsed['exercises'] as List?"));
    expect(restore,contains("parsed['personalRecords'] as List?"));
  });

  test('local backup restore rechecks workout safety after confirmation',(){
    final source=File(
      'lib/features/sync/presentation/backup_status_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('static Future<void> _restoreLocalBackup(');
    final restore=source.substring(start);
    final first=restore.indexOf('ref.read(activeWorkoutProvider).session != null');
    final dialog=restore.indexOf('final confirm = await showDialog<bool>(');
    final confirm=restore.indexOf('if (confirm != true) return;');
    final second=restore.indexOf('ref.read(activeWorkoutProvider).session != null',
      first+1);
    final write=restore.indexOf('await _backupService.restoreBackup(');
    expect(first,greaterThanOrEqualTo(0));
    expect(dialog,greaterThan(first));
    expect(confirm,greaterThan(dialog));
    expect(second,greaterThan(confirm));
    expect(write,greaterThan(second));
    expect(restore,contains('Termina tu entrenamiento actual antes de restaurar una copia.'));
  });

  test('backup data is preflighted before replacing metadata, history or routines',(){
    final source=File(
      'lib/core/services/backup_service.dart',
    ).readAsStringSync();
    final begin=source.indexOf('Future<void> restoreBackup(');
    final end=source.indexOf('Map<String, dynamic> _exerciseToMap',begin);
    expect(begin,greaterThanOrEqualTo(0));
    expect(end,greaterThan(begin));
    final restore=source.substring(begin,end);
    expect(restore.indexOf('_mapDataToHiveObjects(data, schemaVersion)'),
      lessThan(restore.indexOf('await metaBox.clear();')));
    expect(restore,contains('snapshotHistory'));
    expect(restore,contains('snapshotRoutines'));
    expect(restore,contains('await historyBox.putAll(snapshotHistory);'));
    expect(restore,contains('await routinesBox.putAll(snapshotRoutines);'));
    expect(source,contains('_rejectDuplicateRecordIds(data);'));
  });
}
