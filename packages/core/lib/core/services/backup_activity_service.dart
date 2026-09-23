import 'package:core/database/hive/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device-local operational metadata for backup UX.
///
/// It intentionally lives in the derived analytics-cache box rather than the
/// metadata box serialized by BackupService. These timestamps describe this
/// device's actions and must not travel inside a user-data backup.
class BackupActivityService {
  const BackupActivityService._();

  static const lastLocalExportKey = 'backup_activity_last_local_export_at';
  static const lastRestoreKey = 'backup_activity_last_restore_at';
  static const lastRestoreSourceKey = 'backup_activity_last_restore_source';

  static Box<dynamic> get _box => Hive.box(HiveBoxes.analyticsCache);

  static DateTime? get lastLocalExportAt =>
      _readDate(_box.get(lastLocalExportKey));

  static DateTime? get lastRestoreAt => _readDate(_box.get(lastRestoreKey));

  static String? get lastRestoreSource {
    final value = _box.get(lastRestoreSourceKey)?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> markLocalExported({DateTime? at}) async {
    await _box.put(
      lastLocalExportKey,
      (at ?? DateTime.now()).toIso8601String(),
    );
  }

  static Future<void> markRestored({
    required String source,
    DateTime? at,
  }) async {
    await _box.putAll({
      lastRestoreKey: (at ?? DateTime.now()).toIso8601String(),
      lastRestoreSourceKey: source.trim().isEmpty ? 'desconocido' : source.trim(),
    });
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
