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
    'exv2_incline_barbell_press',
    'exv2_flat_machine_press',
    'exv2_pushup',
    'exv2_single_arm_pulldown',
    'exv2_chest_supported_db_row',
    'exv2_single_arm_db_row',
    'ex_face_pull',
    'exv2_arnold_press',
    'exv2_seated_db_lateral_raise',
    'exv2_single_arm_rear_cable_fly',
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
    expect(draftIds, hasLength(20));
    expect(batches.first['target'], 40);
    expect((batches.first['items'] as List<dynamic>)
        .where((entry) => (entry as Map<String, dynamic>)['status'] == 'draft')
        .length, 20);
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
      expect(file.lengthSync(), lessThan(120000), reason: id);
      expect(file.readAsStringSync().toLowerCase(),
          isNot(contains('.gif')), reason: id);
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
          expect(keys[0]['s'], equals(keys[2]['s']),
              reason: 'Draft must return to the same loop frame: $id');
          expect(keys[2]['s'], equals(keys[3]['s']),
              reason: 'Loop ending must not jump at reset: $id');
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

  test('new cable, machine and unilateral variants stay separate by ID', () {
    const expected = <String>{
      'exv2_incline_barbell_press',
      'exv2_flat_machine_press',
      'exv2_pushup',
      'exv2_single_arm_pulldown',
      'exv2_chest_supported_db_row',
      'exv2_single_arm_db_row',
      'ex_face_pull',
      'exv2_arnold_press',
      'exv2_seated_db_lateral_raise',
      'exv2_single_arm_rear_cable_fly',
    };
    expect(draftIds.containsAll(expected), isTrue);
    expect(expected.length, 10);
    for (final id in expected) {
      final json = jsonDecode(
          File('assets/exercise_media/lottie/$id.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(json['nm'], contains(id));
      expect(json['assets'], isEmpty);
    }
  });

  test('draft compositions are specific to their exercise and perspective', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final batches = manifest['batches'] as List<dynamic>;
    final items = batches.expand((batch) =>
        (batch as Map<String, dynamic>)['items'] as List<dynamic>);
    final staged = items
        .cast<Map<String, dynamic>>()
        .where((item) => item['status'] == 'draft')
        .toList();
    expect(staged.length, 20);
    expect(staged.map((item) => item['id']).toSet(), draftIds);
    final uniqueCompositions = <String>{};
    for (final entry in staged) {
      final id = entry['id'] as String;
      final view = entry['view'] as String;
      final json = jsonDecode(
          File(entry['assetPath'] as String).readAsStringSync())
          as Map<String, dynamic>;
      expect(json['nm'], contains(' / $id / $view / '));
      expect(uniqueCompositions.add(jsonEncode(json['layers'])), isTrue,
          reason: 'Different exercise variants need different animations');
      for (final layer in json['layers'] as List<dynamic>) {
        final item = layer as Map<String, dynamic>;
        expect(item['ty'], 4, reason: 'Only vector shape layers');
        expect(item['nm'], isNotEmpty);
      }
      expect(entry['approved'], isFalse);
    }
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
