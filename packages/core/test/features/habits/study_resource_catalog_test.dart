import 'dart:io';

import 'package:core/features/habits/application/study_resource_catalog.dart';
import 'package:core/features/habits/data/study_resource_bookmark_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('catalog exposes only entries with explicit source and license', () {
    expect(StudyResourceCatalog.resources, isNotEmpty);
    for (final resource in StudyResourceCatalog.resources) {
      expect(resource.source.trim(), isNotEmpty);
      expect(resource.licenseName.trim(), isNotEmpty);
    }
  });

  test('catalog search matches title author source license and topic', () {
    expect(
      StudyResourceCatalog.search('reina').single.id,
      'rv1909',
    );
    expect(
      StudyResourceCatalog.search('personal').map((r) => r.id),
      contains('personal_notes'),
    );
    expect(
      StudyResourceCatalog.search('planes').map((r) => r.id),
      contains('stk_study_plans'),
    );
  });

  group('StudyResourceBookmarkRepository', () {
    late Directory temp;
    late Box<dynamic> box;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('study_resource_marks_');
      Hive.init(temp.path);
      box = await Hive.openBox<dynamic>('marks');
    });

    tearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    test('bookmarks are local and removable', () async {
      final repository = StudyResourceBookmarkRepository(box);
      await repository.setBookmarked('rv1909', true);
      expect(repository.getBookmarks(), {'rv1909'});
      await repository.setBookmarked('rv1909', false);
      expect(repository.getBookmarks(), isEmpty);
    });
  });
}
