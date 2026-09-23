import 'package:hive_flutter/hive_flutter.dart';
import 'migration_v1_to_v2.dart';

abstract class Migration {
  final int fromVersion;
  final int toVersion;

  const Migration(this.fromVersion, this.toVersion);

  Future<void> execute();
}

class MigrationRunner {
  static Future<void> runMigrations(
    int currentVersion,
    int targetVersion,
  ) async {
    final availableMigrations = <Migration>[
      MigrationV0ToV1(),
      MigrationV1ToV2(),
    ]..sort((a, b) => a.fromVersion.compareTo(b.fromVersion));

    int version = currentVersion;
    while (version < targetVersion) {
      Migration? nextMigration;
      for (final migration in availableMigrations) {
        if (migration.fromVersion == version) {
          nextMigration = migration;
          break;
        }
      }

      if (nextMigration == null) {
        throw StateError(
          'Falta una migración de base de datos desde la versión $version '
          'hasta $targetVersion. No se actualizará db_version.',
        );
      }

      try {
        await nextMigration.execute();
        version = nextMigration.toVersion;
      } catch (e) {
        throw Exception(
          'Fallo en migración de versión ${nextMigration.fromVersion} '
          'a ${nextMigration.toVersion}: $e',
        );
      }

      if (version > targetVersion) {
        throw StateError(
          'La migración avanzó a una versión inesperada ($version) '
          'superior al objetivo ($targetVersion).',
        );
      }
    }
  }
}

class MigrationV0ToV1 extends Migration {
  MigrationV0ToV1() : super(0, 1);

  @override
  Future<void> execute() async {
    await Hive.deleteBoxFromDisk('routinesBox');
    await Hive.deleteBoxFromDisk('historyBox');
    await Hive.deleteBoxFromDisk('routinesBox_v1');
    await Hive.deleteBoxFromDisk('historyBox_v1');
    await Hive.deleteBoxFromDisk('exercisesBox_v1');
  }
}
