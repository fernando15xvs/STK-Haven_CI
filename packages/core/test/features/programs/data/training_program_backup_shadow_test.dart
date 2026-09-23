import 'dart:io';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> metadata;
  late Box<dynamic> programs;
  late TrainingProgramRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stk_program_backup_');
    Hive.init(tempDir.path);
    metadata = await Hive.openBox<dynamic>(HiveBoxes.metadata);
    programs = await Hive.openBox<dynamic>(HiveBoxes.trainingPrograms);
    repository = TrainingProgramRepository(programs, metadataBox: metadata);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('old backup without program shadow does not retain stale program box', () async {
    final stale = _program('stale', 'Programa que no pertenece al backup');
    await repository.save(stale);
    expect(repository.getAll(), hasLength(1));
    expect(programs.isNotEmpty, isTrue);

    // BackupService clears/replaces metadata. A pre-Programs backup has no
    // training_programs_v2 key, while the optimized box may still contain old
    // device state because it is not part of the legacy payload.
    await metadata.clear();

    expect(repository.getAll(), isEmpty);
    await repository.hydrateFromBackupMetadata();
    expect(programs.isEmpty, isTrue);
  });

  test('restored shadow wins over stale optimized box and can rehydrate it', () async {
    final stale = _program('stale', 'Programa viejo');
    final restored = _program('restored', 'Programa del backup');

    await programs.put(stale.id, stale.toJson());
    await metadata.put(
      TrainingProgramRepository.backupMetadataKey,
      [restored.toJson()],
    );

    final visible = repository.getAll();
    expect(visible, hasLength(1));
    expect(visible.single.id, 'restored');

    await repository.hydrateFromBackupMetadata();
    expect(programs.length, 1);
    expect(programs.containsKey('stale'), isFalse);
    expect(programs.containsKey('restored'), isTrue);
  });
}

TrainingProgram _program(String id, String name) {
  final date = DateTime(2026, 9, 1);
  return TrainingProgram(
    id: id,
    name: name,
    routineIds: const ['a', 'b', 'c'],
    createdAt: date,
    startedAt: date,
    durationWeeks: 8,
  );
}
