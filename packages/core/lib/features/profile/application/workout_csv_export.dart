import 'package:core/domain/models/workout_session.dart';
import 'package:csv/csv.dart';

/// Pure Dart CSV schema: same BOM, headings, order, date/weight/rep formatting
/// as the legacy export. No filesystem, temporary path or share sheet here.
abstract final class WorkoutCsvExport {
  static String encode(List<WorkoutSession> sessions) =>
      '\uFEFF${Csv().encode(buildRows(sessions))}';

  static List<List<dynamic>> buildRows(List<WorkoutSession> sessions) {
    final rows = <List<dynamic>>[
      [
        'Fecha',
        'Rutina',
        'Duración (min)',
        'Ejercicio',
        'Serie',
        'Peso',
        'Repeticiones',
        'RIR',
        'Completada',
        'Unilateral',
        'Peso izquierda',
        'Reps izquierda',
        'RIR izquierda',
        'Izquierda completada',
        'Peso derecha',
        'Reps derecha',
        'RIR derecha',
        'Derecha completada',
        'Descanso entre lados (s)',
      ],
    ];
  
    for (final session in sessions) {
      final date = session.startedAt.toIso8601String().split('T').first;
      final duration = (session.durationSeconds / 60).toStringAsFixed(1);
      for (final exercise in session.exercises) {
        for (var index = 0; index < exercise.sets.length; index++) {
          final set = exercise.sets[index];
          rows.add([
            date,
            session.routineNameSnapshot,
            duration,
            exercise.exerciseNameSnapshot,
            index + 1,
            set.weight,
            set.reps,
            set.rir ?? '',
            set.completed ? 'Sí' : 'No',
            exercise.unilateral ? 'Sí' : 'No',
            set.leftWeight ?? '',
            set.leftReps ?? '',
            set.leftRir ?? '',
            set.leftCompleted ? 'Sí' : 'No',
            set.rightWeight ?? '',
            set.rightReps ?? '',
            set.rightRir ?? '',
            set.rightCompleted ? 'Sí' : 'No',
            set.sideRestSeconds,
          ]);
        }
      }
    }
  
    return rows;
  }
  
}
