import 'dart:convert';
import 'dart:io';

import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifestPath = 'tool/exercise_lottie_batches.json';
  const draftIds = <String>{
    'ex_bench_press',
    'ex_lat_pulldown',
    'ex_lateral_raises',
    'ex_incline_db_press',
    'exv2_flat_db_press',
    'ex_pullups',
    'ex_barbell_row',
    'ex_cable_row',
    'ex_ohp',
    'ex_squat',
  };

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
        if (draftIds.contains(id)) {
          expect(entry['status'], 'draft');
          expect(entry['view'], anyOf('frontal', 'lateral'));
          expect(entry['origin'], contains('STK Haven'));
          final review = entry['review'] as Map<String, dynamic>;
          expect(review.values, everyElement(isFalse));
        } else {
          expect(entry['status'], 'pending');
        }
        expect(entry['approved'], isFalse);
        final path = entry['assetPath'] as String;
        expect(path, 'assets/exercise_media/lottie/$id.json');
        expect(allAssetPaths.add(path), isTrue, reason: path);
        count++;
      }
    }
    expect(count, 229);
    expect(draftIds, hasLength(10));
    expect(batches.first['target'], 40);
    expect((batches.first['items'] as List<dynamic>)
        .where((entry) => (entry as Map<String, dynamic>)['status'] == 'draft')
        .length, 10);
    expect(allIds, presetExercises.map((e) => e.id).toSet());
    expect((manifest['batches'] as List<dynamic>)
        .expand((batch) => (batch as Map<String, dynamic>)['items'] as List<dynamic>)
        .where((entry) => (entry as Map<String, dynamic>)['approved'] == true),
        isEmpty);
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('first vector drafts contain movement without embedded images', () {
    for (final id in draftIds) {
      final file = File('assets/exercise_media/lottie/$id.json');
      expect(file.existsSync(), isTrue, reason: id);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['fr'], 30);
      expect(json['w'], 512);
      expect(json['h'], 512);
      expect(json['op'], 90);
      expect(json['assets'], isEmpty);
      final layers = json['layers'] as List<dynamic>;
      expect(layers.length, greaterThan(10));
      final animatedShapes = layers.where((layer) {
        final shapes = (layer as Map<String, dynamic>)['shapes'] as List<dynamic>;
        return shapes.any((shape) {
          final item = shape as Map<String, dynamic>;
          if (item['ty'] != 'sh') return false;
          return (item['ks'] as Map<String, dynamic>)['a'] == 1;
        });
      }).length;
      expect(animatedShapes, greaterThanOrEqualTo(3), reason: id);
      for (final layer in layers) {
        final shapes = (layer as Map<String, dynamic>)['shapes']
            as List<dynamic>;
        for (final shape in shapes) {
          final item = shape as Map<String, dynamic>;
          if (item['ty'] != 'sh') continue;
          final ks = item['ks'] as Map<String, dynamic>;
          if (ks['a'] != 1) continue;
          final keys = ks['k'] as List<dynamic>;
          expect(keys.map((key) => key['t']).toList(), [0, 30, 60, 90]);
          expect(jsonEncode(keys[0]['s']),
              isNot(jsonEncode(keys[1]['s'])), reason: id);
        }
      }
      expect(json['nm'], contains(id));
    }
    // Drafts must remain outside shipped Flutter bundles until reviewed.
    // Unreviewed drafts must not be included in a distributed app bundle.
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(contains('assets/exercise_media/lottie/')));
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
