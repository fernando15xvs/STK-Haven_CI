import 'dart:io';

import 'package:core/features/faith/data/reflection_journal_repository.dart';
import 'package:core/domain/models/verse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late ReflectionJournalRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reflection_journal_test');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('metadata');
    repository = ReflectionJournalRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('saves reflection snapshot and keeps newest first', () async {
    const verse = Verse(book: 'Salmos', chapter: 23, verse: 1, text: 'Texto de prueba');
    await repository.saveVerse(
      verse: verse,
      mood: 'Agradecido',
      createdAt: DateTime(2026, 9, 1, 8),
    );
    await repository.saveVerse(
      verse: verse,
      mood: 'General',
      createdAt: DateTime(2026, 9, 2, 8),
    );

    final entries = repository.getEntries();
    expect(entries, hasLength(2));
    expect(entries.first.mood, 'General');
    expect(entries.first.verseReference, 'Salmos 23:1');
  });

  test('updates personal note without changing reflection snapshot', () async {
    const verse = Verse(book: 'Juan', chapter: 3, verse: 16, text: 'Texto');
    final entries = await repository.saveVerse(
      verse: verse,
      mood: 'Esperanza',
      createdAt: DateTime(2026, 9, 2),
    );
    final id = entries.single.id;

    await repository.updateNote(id, '  Recordar esta idea  ');
    final updated = repository.getEntries().single;
    expect(updated.note, 'Recordar esta idea');
    expect(updated.mood, 'Esperanza');
    expect(updated.verseReference, 'Juan 3:16');
  });

  test('deletes an entry and ignores malformed stored values', () async {
    await box.put(ReflectionJournalRepository.storageKey, [
      {'id': '', 'createdAt': 'bad'},
    ]);
    expect(repository.getEntries(), isEmpty);

    const verse = Verse(book: 'Mateo', chapter: 5, verse: 9, text: 'Texto');
    final entries = await repository.saveVerse(verse: verse, mood: 'General');
    await repository.delete(entries.single.id);
    expect(repository.getEntries(), isEmpty);
  });
}
