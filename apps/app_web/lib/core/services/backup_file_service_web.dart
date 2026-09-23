import 'dart:convert';
import 'dart:js_interop';

import 'package:core/core/services/backup_activity_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

class BackupFileService {
  Future<void> exportFile(String jsonContent) async {
    final blob = web.Blob(
      [jsonContent.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);

    try {
      web.HTMLAnchorElement()
        ..href = url
        ..download = 'stk_haven_backup.json'
        ..click();
      await BackupActivityService.markLocalExported();
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty) return null;

      final bytes = await result.first.readAsBytes();
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }
}
