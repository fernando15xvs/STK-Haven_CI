/// Dart-only contract for explicit local export/import actions.
abstract class BackupFileBackend {
  Future<void> exportFile(String jsonContent);
  Future<String?> pickBackupFile();
}

class BackupFileService {
  static BackupFileBackend? _backend;

  static void installBackend(BackupFileBackend? backend) {
    _backend = backend;
  }

  Future<void> exportFile(String jsonContent) =>
      _backend?.exportFile(jsonContent) ??
      Future<void>.error(
        StateError('El selector de archivos requiere la aplicación móvil.'),
      );

  Future<String?> pickBackupFile() =>
      _backend?.pickBackupFile() ?? Future<String?>.value();
}
