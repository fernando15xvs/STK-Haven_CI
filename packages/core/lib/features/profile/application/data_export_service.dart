import 'package:core/domain/models/workout_session.dart';

/// The CSV policy is deterministic; sharing through the OS is Mobile-owned.
abstract class DataExportBackend {
  Future<void> exportWorkoutsToCSV(List<WorkoutSession> sessions);
}

class DataExportService {
  static DataExportBackend? _backend;

  static void installBackend(DataExportBackend? backend) {
    _backend = backend;
  }

  Future<void> exportWorkoutsToCSV(List<WorkoutSession> sessions) =>
      _backend?.exportWorkoutsToCSV(sessions) ??
      Future<void>.error(
        StateError('Exportación disponible solo en la aplicación móvil.'),
      );
}
