import 'package:hive/hive.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:uuid/uuid.dart';
import 'package:core/features/recovery/application/adaptive_recovery.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';

/// Local, immutable start context keyed by session identity. No automatic
/// coach sharing. Metadata participates in existing backup/restore.
class RecoverySessionSnapshot {
  const RecoverySessionSnapshot(this.data);
  final Map<dynamic,dynamic> data;
  bool get adapted => data['adapted'] == true;
  bool get globalCaution => data['globalCaution'] == true;
  bool get pain => data['pain'] == true;
  bool cautions(String exerciseId) => globalCaution || pain ||
      (data['affected'] is List && (data['affected'] as List).contains(exerciseId));
  RecoveryStatus? get status => RecoveryStatus.values.where((v)=>v.name == data['status']).firstOrNull;
  int? get score => data['score'] is int ? data['score'] as int : null;
  int? get sleepMinutes => data['sleepMinutes'] is int ? data['sleepMinutes'] as int : null;
  static String _key(String id) => 'recovery_session_v1_$id';
  static RecoverySessionSnapshot? read(String id) {
    if (!Hive.isBoxOpen(HiveBoxes.metadata)) return null;
    final raw = Hive.box<dynamic>(HiveBoxes.metadata).get(_key(id));
    return raw is Map ? RecoverySessionSnapshot(Map.unmodifiable(raw)) : null;
  }
  static String newSessionId() => const Uuid().v4();

  static Future<void> capture(String sessionId, DateTime startedAt, RecoverySessionAdvice advice,
      SleepDiary sleep, RecoveryCheckIn? checkIn, {required bool adapted}) async {
    if (!Hive.isBoxOpen(HiveBoxes.metadata)) return;
    final box = Hive.box<dynamic>(HiveBoxes.metadata);
    if (box.containsKey(_key(sessionId))) return;
    final valid = checkIn != null &&
      SleepDiary.dayKey(checkIn.date) == SleepDiary.dayKey(startedAt) &&
      !checkIn.updatedAt.isAfter(startedAt) ? checkIn : null;
    await box.put(_key(sessionId), {
      'startedAt':startedAt.toIso8601String(),
      'score': valid?.score,
      'status': valid?.status.name,
      'sleepMinutes':sleep.minutesFor(startedAt),
      'sleepQuality':sleep.qualityFor(startedAt) ?? valid?.sleep,
      'adapted':adapted,'globalCaution':advice.globalCaution,'pain':advice.pain,
      'affected':advice.affectedIds.toList(),'reasons':advice.reasons,
    });
  }
  static Future<void> discard(String id) async {
    if (Hive.isBoxOpen(HiveBoxes.metadata)) {
      await Hive.box<dynamic>(HiveBoxes.metadata).delete(_key(id));
    }
  }
}
