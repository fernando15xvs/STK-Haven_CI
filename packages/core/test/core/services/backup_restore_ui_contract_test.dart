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
    final first=restore.indexOf('final activeWorkout = ref.read(activeWorkoutProvider);');
    final dialog=restore.indexOf('final confirm = await showDialog<bool>(');
    final confirm=restore.indexOf('if (!context.mounted || confirm != true) return;');
    final second=restore.indexOf('ref.read(activeWorkoutProvider).session != null',
      confirm);
    final write=restore.indexOf('await _backupService.restoreBackup(');
    expect(first,greaterThanOrEqualTo(0));
    expect(dialog,greaterThan(first));
    expect(confirm,greaterThan(dialog));
    expect(second,greaterThan(confirm));
    expect(write,greaterThan(second));
    expect(restore,contains('Termina tu entrenamiento actual antes de restaurar una copia.'));
  });

  test('cloud backup cannot restore into a different signed-in account',(){
    final source=File(
      'lib/features/sync/application/cloud_sync_provider.dart',
    ).readAsStringSync();
    final start=source.indexOf('Future<bool> restoreFromCloud() async');
    final end=source.indexOf('void _invalidateRestoredState()',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final restore=source.substring(start,end);
    final selection=restore.indexOf(".eq('user_id', identity.userId!)");
    final freshIdentity=restore.indexOf(
      'final currentIdentity = ref.read(appIdentityProvider);');
    final guard=restore.indexOf('currentIdentity.userId != identity.userId');
    final active=restore.indexOf(
      'ref.read(activeWorkoutProvider).session != null',guard);
    final write=restore.indexOf('await _backupService.restoreBackup(');
    expect(selection,greaterThanOrEqualTo(0));
    expect(freshIdentity,greaterThan(selection));
    expect(guard,greaterThan(freshIdentity));
    expect(active,greaterThan(guard));
    expect(write,greaterThan(active));
    expect(restore,contains('!currentIdentity.signedIn'));
    expect(restore,contains(
      'La cuenta cambió durante la descarga. No se restauró la copia.'));
  });

  test('local restore UI never renders raw Hive/native exception details',(){
    final screen=File(
      'lib/features/sync/presentation/backup_status_page.dart',
    ).readAsStringSync();
    final start=screen.indexOf('static Future<void> _restoreLocalBackup(');
    expect(start,greaterThanOrEqualTo(0));
    final restore=screen.substring(start);
    expect(restore,contains('catch (_)'));
    expect(restore,contains('conserva el archivo de respaldo.'));
    expect(restore,isNot(contains(r'Error al restaurar la copia: $error')));
    final service=File(
      'lib/core/services/backup_service.dart',
    ).readAsStringSync();
    expect(service,contains('La restauración falló y no se pudo confirmar'));
    expect(service,contains('Se recuperaron los datos locales anteriores.'));
    expect(service,isNot(contains(r'Error: $e')));
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
  test('A5: exports never reveal file paths from native share errors',(){
    final source=File(
      'lib/features/sync/presentation/backup_status_page.dart',
    ).readAsStringSync();
    expect(source,contains(
      'No se pudo exportar la copia. '));
    expect(source,contains(
      'No se pudieron exportar los entrenamientos. '));
    expect(source,isNot(contains(r'Error al crear la copia: $error')));
    expect(source,isNot(contains(r'Error al exportar entrenamientos: $error')));
  });

  test('A5: local restore status is written after Hive and program hydration',(){
    final source=File(
      'lib/features/sync/presentation/backup_status_page.dart',
    ).readAsStringSync();
    final start=source.indexOf('static Future<void> _restoreLocalBackup(');
    final restore=source.substring(start);
    final persisted=restore.indexOf('await _backupService.restoreBackup(');
    final hydrated=restore.indexOf(
      'await TrainingProgramRepository.fromHive().hydrateFromBackupMetadata();');
    final status=restore.indexOf(
      "await BackupActivityService.markRestored(source: 'local');");
    final invalidate=restore.indexOf('ref.invalidate(settingsProvider);');
    expect(persisted,greaterThanOrEqualTo(0));
    expect(hydrated,greaterThan(persisted));
    expect(status,greaterThan(hydrated));
    expect(invalidate,greaterThan(status));
    // An unsuccessful restore must stay in the catch block and never claim
    // the backup was committed.
    expect(restore,contains('catch (_)'));
  });

  test('B1.7 legacy recovery is an opt-in preview with confirmation',(){
    final ui = File('lib/features/sync/presentation/backup_status_page.dart')
        .readAsStringSync();
    expect(ui, contains('Recuperar datos de una versión antigua'));
    final start=ui.indexOf('static Future<void> _importLegacyArchives(');
    final end=ui.indexOf('static Future<void> _restoreLocalBackup(',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final flow=ui.substring(start,end);
    final preview=flow.indexOf('await importer.inspect()');
    final safe=flow.indexOf('if (!scan.safeToImport)');
    final dialog=flow.indexOf('final confirmed = await showDialog<bool>(');
    final confirmed=flow.indexOf('confirmed != true');
    final guard=flow.lastIndexOf('ref.read(activeWorkoutProvider).session != null');
    final write=flow.indexOf('await importer.importRecognized()');
    expect(preview,greaterThanOrEqualTo(0));
    expect(safe,greaterThan(preview));
    expect(dialog,greaterThan(safe));
    expect(confirmed,greaterThan(dialog));
    expect(guard,greaterThan(confirmed));
    expect(write,greaterThan(guard));
    expect(flow,contains('pueden pertenecer a otra cuenta'));
    expect(flow,contains('No se subirán automáticamente a la nube.'));
    expect(flow,contains("markRestored(source: 'archivo antiguo')"));
    expect(flow,isNot(contains('Hive.deleteBoxFromDisk(')));
  });

}
