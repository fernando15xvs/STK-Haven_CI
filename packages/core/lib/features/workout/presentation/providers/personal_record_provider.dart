import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../database/hive/hive_boxes.dart';
import '../../../../database/hive/models/hive_personal_record.dart';
import 'package:core/features/workout/data/personal_record_repository.dart';

final personalRecordRepositoryProvider = Provider<PersonalRecordRepository>((ref) {
  final box = Hive.box<HivePersonalRecord>(HiveBoxes.personalRecords);
  return PersonalRecordRepository(box);
});
