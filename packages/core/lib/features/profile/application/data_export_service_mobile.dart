import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:core/domain/models/workout_session.dart';

class DataExportService {
  Future<void> exportWorkoutsToCSV(List<WorkoutSession> sessions) async {
    final csvWithBom = '\uFEFF${Csv().encode(_buildRows(sessions))}';
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/entrenamientos_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvWithBom);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Aquí tienes mis entrenamientos exportados.',
      ),
    );
  }
}

List<List<dynamic>> _buildRows(List<WorkoutSession> sessions) {
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
