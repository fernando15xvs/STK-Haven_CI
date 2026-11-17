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
    // Legacy Hive boxes can contain workouts/routines that were never copied
    // into the modern v2 stores. Deleting them during startup permanently
    // discards a user's history. Preserve the original on-disk data: the app
    // opens separate v2 stores, and an explicit legacy import can be offered
    // after adapters/record formats have been validated. This step MUST NOT
    // delete or overwrite legacy boxes, even for installs upgraded from v0.
  }
}
