import 'dart:io';

import 'package:core/database/migrations/database_version.dart';
import 'package:core/database/migrations/migration_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('A5: upgrading from v0 retains all legacy Hive boxes on disk',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'stk_haven_legacy_migration_',
    );
    addTearDown(() async {
      await Hive.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    Hive.init(directory.path);
    const legacyNames = <String>[
      'routinesBox',
      'historyBox',
      'routinesBox_v1',
      'historyBox_v1',
      'exercisesBox_v1',
    ];
    for (final name in legacyNames) {
      final box = await Hive.openBox<dynamic>(name);
      await box.put('original-user-record', <String, dynamic>{
        'id': 'original-user-record',
        'source': name,
        'weight': 72.5,
        'sets': <int>[8, 10, 12],
      });
    }
    await Hive.close();

    // Simulate a process restart and the real upgrade path (0 -> 1 -> 2).
    // No legacy adapter is registered: older records must stay intact even
    // when the current release does not yet know how to decode them.
    Hive.init(directory.path);
    await MigrationRunner.runMigrations(0, currentDatabaseVersion);

    for (final name in legacyNames) {
      final box = await Hive.openBox<dynamic>(name);
      expect(box.containsKey('original-user-record'), isTrue, reason: name);
      final entry = box.get('original-user-record') as Map<dynamic, dynamic>;
      expect(entry['source'], name);
      expect(entry['weight'], 72.5);
      expect(entry['sets'], <int>[8, 10, 12]);
    }
  });

  test('A5: v1 to current does not modify unknown local stores', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stk_haven_legacy_v1_',
    );
    addTearDown(() async {
      await Hive.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('legacy_user_only_box');
    await box.put('private-history', <String, dynamic>{
      'title': 'Entrenamiento anterior',
      'reps': 12,
    });
    await MigrationRunner.runMigrations(1, currentDatabaseVersion);
    expect(box.get('private-history'), <String, dynamic>{
      'title': 'Entrenamiento anterior',
      'reps': 12,
    });
  });

  test('A5: no migration ever deletes pre-v2 Hive box files', () {
    final source = File(
      'lib/database/migrations/migration_runner.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Hive.deleteBoxFromDisk(')));
    expect(source, contains('Legacy Hive boxes can contain workouts/routines'));
  });
}
