import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:core/features/exercises/data/exercise_personal_settings_repository.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late ExercisePersonalSettingsRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stk_exercise_settings_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('metadata_test');
    repository = ExercisePersonalSettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('returns empty defaults for unknown exercise', () {
    final settings = repository.getFor('bench');
    expect(settings.warmupSets, 0);
    expect(settings.approachSets, 0);
    expect(settings.technicalNotes, isEmpty);
  });

  test('persists defaults and technical notes per exercise', () async {
    await repository.save(
      'bench',
      const ExercisePersonalSettings(
        warmupSets: 2,
        approachSets: 1,
        technicalNotes: '  Escápulas atrás y pausa.  ',
      ),
    );

    final settings = repository.getFor('bench');
    expect(settings.warmupSets, 2);
    expect(settings.approachSets, 1);
    expect(settings.technicalNotes, 'Escápulas atrás y pausa.');
  });

  test('normalizes invalid set counts and ignores malformed entries', () async {
    await box.put(ExercisePersonalSettingsRepository.storageKey, {
      'squat': {
        'warmupSets': 99,
        'approachSets': -3,
        'technicalNotes': ' Controlar profundidad ',
      },
      'bad': 'not-a-map',
      '': {'warmupSets': 1},
    });

    final all = repository.getAll();
    expect(all.keys, ['squat']);
    expect(all['squat']!.warmupSets, 5);
    expect(all['squat']!.approachSets, 0);
    expect(all['squat']!.technicalNotes, 'Controlar profundidad');
  });

  test('remove only deletes the selected exercise settings', () async {
    await repository.save(
      'bench',
      const ExercisePersonalSettings(warmupSets: 1),
    );
    await repository.save(
      'row',
      const ExercisePersonalSettings(approachSets: 2),
    );

    await repository.remove('bench');

    expect(repository.getAll().containsKey('bench'), isFalse);
    expect(repository.getFor('row').approachSets, 2);
  });
}
