import 'dart:convert';
import 'dart:io';

import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifestPath = 'tool/exercise_lottie_batches.json';

  test('229 exercise IDs appear exactly once in four planned mobile batches',
      () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    expect(manifest['scope'], 'mobile-only');
    expect(manifest['appPackage'], 'apps/app_mobile');
    final targets = manifest['targets'] as Map<String, dynamic>;
    expect(targets['ios'], 229);
    expect(targets['android'], 229);
    expect(targets['web'], 0);

    final batches = manifest['batches'] as List<dynamic>;
    expect(batches, hasLength(4));
    expect([
      for (final batch in batches)
        (batch as Map<String, dynamic>)['target'],
    ], [40, 60, 70, 59]);

    final allIds = <String>{};
    final allAssetPaths = <String>{};
    var count = 0;
    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i] as Map<String, dynamic>;
      expect(batch['lot'], i + 1);
      expect(batch['platforms'], ['android', 'ios']);
      final items = batch['items'] as List<dynamic>;
      expect(items.length, batch['target']);
      for (final item in items) {
        final entry = item as Map<String, dynamic>;
        final id = entry['id'] as String;
        expect(allIds.add(id), isTrue, reason: 'Repeated $id');
        expect(entry['name'], isNotEmpty);
        expect(entry['family'], isNotEmpty);
        expect(entry['mediaFormat'], 'lottie');
        expect(entry['status'], 'pending');
        expect(entry['approved'], isFalse);
        final path = entry['assetPath'] as String;
        expect(path, 'assets/exercise_media/lottie/$id.json');
        expect(allAssetPaths.add(path), isTrue, reason: path);
        count++;
      }
    }
    expect(count, 229);
    expect(allIds, presetExercises.map((e) => e.id).toSet());
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('Lottie code and dependencies are mobile-only, not the web app', () {
    final mobile = File('pubspec.yaml').readAsStringSync();
    final web = File('../app_web/pubspec.yaml').readAsStringSync();
    expect(mobile, contains('lottie: 3.3.3'));
    expect(web, isNot(contains('lottie:')));
    expect(web, isNot(contains('assets/exercise_media')));
    expect(web, isNot(contains('exercise_lottie_batches.json')));
  });
}
