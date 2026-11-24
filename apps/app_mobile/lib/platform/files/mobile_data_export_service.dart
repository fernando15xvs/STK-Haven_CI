import 'package:core/features/profile/application/data_export_service.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/profile/application/workout_csv_export.dart';

class MobileDataExportService {
  Future<void> exportWorkoutsToCSV(List<WorkoutSession> sessions) async {
    final csvWithBom = WorkoutCsvExport.encode(sessions);
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

