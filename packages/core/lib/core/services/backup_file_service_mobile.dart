import 'dart:io';

import 'package:core/core/services/backup_activity_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class BackupFileService {
  Future<void> exportFile(String jsonContent) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/stk_haven_backup.json');
    await file.writeAsString(jsonContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Backup de STK Haven',
      ),
    );
    await BackupActivityService.markLocalExported();
  }

  Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        return await file.readAsString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
