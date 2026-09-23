import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/models/personal_record.dart';
import '../../../database/hive/models/hive_personal_record.dart';

class PersonalRecordRepository {
  final Box<HivePersonalRecord> _box;

  PersonalRecordRepository(this._box);

  List<PersonalRecordEvent> getAllPRs() {
    return _box.values.map(_fromHive).toList();
  }

  List<PersonalRecordEvent> getPRsForExercise(String exerciseId) {
    return _box.values
        .where((pr) => pr.exerciseId == exerciseId)
        .map(_fromHive)
        .toList();
  }

  double? getBestValue(String exerciseId, PRType type) {
    final prs = _box.values.where(
      (pr) => pr.exerciseId == exerciseId && _fromHiveType(pr.type) == type,
    );
    if (prs.isEmpty) return null;
    return prs.map((e) => e.newValue).reduce((a, b) => a > b ? a : b);
  }

  Future<void> savePRs(List<PersonalRecordEvent> prs) async {
    for (final pr in prs) {
      await _box.put(pr.id, _toHive(pr));
    }
  }

  PersonalRecordEvent _fromHive(HivePersonalRecord hive) {
    return PersonalRecordEvent(
      id: hive.id,
      workoutSessionId: hive.workoutSessionId,
      exerciseId: hive.exerciseId,
      exerciseNameSnapshot: hive.exerciseNameSnapshot,
      type: _fromHiveType(hive.type),
      previousValue: hive.previousValue,
      newValue: hive.newValue,
      achievedAt: hive.achievedAt,
    );
  }

  HivePersonalRecord _toHive(PersonalRecordEvent model) {
    return HivePersonalRecord(
      id: model.id,
      workoutSessionId: model.workoutSessionId,
      exerciseId: model.exerciseId,
      exerciseNameSnapshot: model.exerciseNameSnapshot,
      type: _toHiveType(model.type),
      previousValue: model.previousValue,
      newValue: model.newValue,
      achievedAt: model.achievedAt,
    );
  }

  PRType _fromHiveType(HivePRType type) {
    switch (type) {
      case HivePRType.maxWeight:
        return PRType.maxWeight;
      case HivePRType.estimated1RM:
        return PRType.estimated1RM;
      case HivePRType.bestSetVolume:
        return PRType.bestSetVolume;
    }
  }

  HivePRType _toHiveType(PRType type) {
    switch (type) {
      case PRType.maxWeight:
        return HivePRType.maxWeight;
      case PRType.estimated1RM:
        return HivePRType.estimated1RM;
      case PRType.bestSetVolume:
        return HivePRType.bestSetVolume;
    }
  }
}
