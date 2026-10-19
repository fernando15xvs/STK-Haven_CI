import 'dart:convert';
import 'dart:io';

import 'package:core/core/constants/preset_exercises.dart';
import 'package:core/features/exercises/application/exercise_demonstration_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

Iterable<Map<String, dynamic>> _allShapes(List<dynamic> shapes) sync* {
  for (final raw in shapes) {
    final item = raw as Map<String, dynamic>;
    if (item['ty'] == 'gr') {
      yield* _allShapes(item['it'] as List<dynamic>);
    } else {
      yield item;
    }
  }
}

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
    'exv2_scapular_pushup',
    'ex_barbell_curl',
    'ex_hammer_curl',
    'ex_tricep_pushdown',
    'exv2_ez_bar_curl',
    'exv2_rope_pushdown',
    'exv2_rope_hammer_curl',
    'ex_leg_press',
    'ex_leg_extension',
    'ex_leg_curl',
    'ex_hip_thrust',
    'ex_rdl',
    'exv2_front_squat',
    'exv2_goblet_squat',
    'exv2_db_rdl',
    'exv2_machine_hip_thrust',
    'exv2_nordic_curl',
    'ex_calf_raise',
    'ex_crunch',
    'exv2_pallof_press',
    'exv2_preacher_bar_curl',
    'exv2_barbell_glute_bridge',
    'exv2_cable_crunch',
    'exv2_seated_barbell_ohp',
    'exv2_incline_smith_press',
    'exv2_smith_squat',
    'exv2_standing_calf_raise',
    'exv2_band_pull_apart',
    'exv2_wrist_curl_seated',
    'exv2_roman_chair_back_extension',
    'exv2_chinup',
    'exv2_glute_ham_raise',
    'exv2_chest_supported_machine_row',
    'ex_chest_flyes',
    'ex_overhead_tricep',
    'ex_db_curl',
    'ex_kelso_shrugs',
    'ex_db_shoulder_press',
    'ex_lying_leg_curl',
    'ex_bulgarian_split_squat',
    'ex_abductor',
    'ex_adductor',
    'exv2_preacher_machine_curl',
    'exv2_smith_hip_thrust',
    'exv2_machine_crunch',
    'exv2_landmine_shoulder_press',
    'exv2_incline_machine_press',
    'exv2_hack_squat',
    'exv2_seated_calf_raise',
    'exv2_scapular_row',
    'exv2_reverse_wrist_curl',
    'exv2_cable_pullthrough',
    'exv2_assisted_pullup',
    'exv2_swiss_ball_leg_curl',
    'exv2_meadows_row',
    'ex_cable_crossover',
    'ex_dips',
    'ex_incline_db_curl',
    'ex_machine_unilateral_row',
    'ex_reverse_pec_deck',
    'ex_seated_leg_curl',
    'ex_pendulum_squat',
    'exv2_spider_curl',
    'exv2_single_leg_hip_thrust',
    'exv2_reverse_crunch',
    'exv2_machine_shoulder_press',
    'exv2_decline_barbell_press',
    'exv2_belt_squat',
    'exv2_smith_calf_raise',
    'exv2_cable_scapular_retraction',
    'exv2_wrist_roller',
    'exv2_reverse_hyper',
    'exv2_band_pullup',
    'exv2_slider_leg_curl',
    'exv2_landmine_row',
    'ex_peck_deck',
    'ex_v_bar_pushdown',
    'ex_low_pulley_curl',
    'ex_t_bar_row',
    'ex_machine_lateral_raises',
    'ex_standing_leg_curl',
    'exv2_bayesian_curl',
    'exv2_cable_glute_kickback',
    'exv2_hanging_knee_raise',
    'exv2_lean_away_lateral_raise',
    'exv2_decline_db_press',
    'exv2_horizontal_leg_press',
    'exv2_single_leg_db_calf',
    'exv2_barbell_shrug',
    'exv2_hammer_pronation',
    'exv2_good_morning',
    'exv2_wide_pulldown',
    'exv2_cable_leg_curl',
    'exv2_low_cable_single_arm_row',
    'ex_hammer_press',
    'ex_french_press',
    'ex_unilateral_scott_hammer',
    'ex_neutral_pulldown',
    'ex_cable_rear_delt',
    'exv2_incline_alternating_curl',
    'exv2_machine_glute_kickback',
    'exv2_captains_chair_raise',
    'exv2_behind_body_cable_lateral',
    'exv2_incline_pushup',
    'exv2_unilateral_leg_press',
    'exv2_leg_press_calf_raise',
    'exv2_db_shrug',
    'exv2_hammer_supination',
    'exv2_single_leg_rdl',
    'exv2_supine_pulldown',
    'exv2_lying_leg_curl_unilateral',
    'exv2_inverted_row',
    'ex_high_pulley_fly',
    'ex_machine_dips',
    'exv2_standing_cable_curl',
    'exv2_stepback_cable_glute',
    'exv2_decline_crunch',
    'exv2_front_plate_raise',
    'exv2_decline_pushup',
    'exv2_step_up',
    'exv2_donkey_calf_raise',
    'exv2_cable_shrug',
    'exv2_farmer_carry',
    'exv2_smith_rdl',
    'exv2_straight_arm_pulldown',
    'exv2_seated_leg_curl_unilateral',
    'exv2_high_cable_curl',
    'exv2_frog_pumps',
    'exv2_weighted_crunch',
    'exv2_front_cable_raise',
    'exv2_flat_db_fly',
    'exv2_reverse_lunge',
    'exv2_bent_knee_calf_raise',
    'exv2_prone_y_raise',
    'exv2_dead_hang',
    'exv2_stiff_leg_deadlift',
    'exv2_machine_pullover',
    'exv2_concentration_curl',
    'exv2_side_lying_hip_abduction',
    'exv2_dead_bug',
    'exv2_incline_rear_delt_fly',
    'exv2_low_to_high_fly',
    'exv2_walking_lunge',
    'exv2_single_leg_seated_calf',
    'exv2_prone_t_raise',
    'exv2_plate_pinch',
    'exv2_sumo_deadlift',
    'exv2_db_pullover',
    'exv2_supinated_single_cable_curl',
    'exv2_cable_hip_abduction',
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
    expect(draftIds, hasLength(170));
    expect(batches.first['target'], 40);
    expect((batches.first['items'] as List<dynamic>)
        .where((entry) => (entry as Map<String, dynamic>)['status'] == 'draft')
        .length, 40);
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
        final shapes = _allShapes(
            (layer as Map<String, dynamic>)['shapes'] as List<dynamic>);
        return shapes.any((shape) {
          final item = shape;
          if (item['ty'] != 'sh') return false;
          return (item['ks'] as Map<String, dynamic>)['a'] == 1;
        });
      }).length;
      expect(animatedShapes, greaterThanOrEqualTo(3), reason: id);
      for (final layer in layers) {
        final shapes = _allShapes((layer as Map<String, dynamic>)['shapes']
            as List<dynamic>);
        for (final shape in shapes) {
          final item = shape;
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
      for (final rawLayer in layers) {
        final layer = rawLayer as Map<String, dynamic>;
        final top = layer['shapes'] as List<dynamic>;
        expect(top, hasLength(1), reason: id);
        final group = top.single as Map<String, dynamic>;
        expect(group['ty'], 'gr', reason: id);
        final contents = group['it'] as List<dynamic>;
        expect(contents.last['ty'], 'tr', reason: id);
      }
      expect(json['nm'], contains(id));
    }
    // Drafts must remain outside shipped Flutter bundles until reviewed.
    // Unreviewed drafts must not be included in a distributed app bundle.
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(contains('assets/exercise_media/lottie/')));
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('all 170 drafts parse in the mobile Lottie 3.3.3 decoder', () async {
    for (final id in draftIds) {
      final bytes = File('assets/exercise_media/lottie/$id.json')
          .readAsBytesSync();
      LottieComposition composition;
      try {
        composition = await LottieComposition.fromBytes(bytes);
      } catch (error) {
        fail('Lottie parser rejected $id: $error');
      }
      expect(composition.duration, greaterThan(Duration.zero), reason: id);
      expect(composition.bounds.width, 512, reason: id);
      expect(composition.bounds.height, 512, reason: id);
    }
  });

  test('draft color values use Lottie-compatible normalized RGBA vectors', () {
    for (final id in draftIds) {
      final json = jsonDecode(
          File('assets/exercise_media/lottie/$id.json').readAsStringSync())
          as Map<String, dynamic>;
      for (final rawLayer in json['layers'] as List<dynamic>) {
        final layer = rawLayer as Map<String, dynamic>;
        for (final shape in _allShapes(layer['shapes'] as List<dynamic>)) {
          if (shape['ty'] != 'st' && shape['ty'] != 'fl') continue;
          final color = shape['c'] as Map<String, dynamic>;
          expect(color['a'], 0, reason: '$id: ${layer['nm']}');
          final rgba = color['k'];
          expect(rgba, isA<List<dynamic>>(),
              reason: '$id: ${layer['nm']} has malformed color');
          final channels = rgba as List<dynamic>;
          expect(channels, hasLength(4), reason: id);
          for (final channel in channels) {
            expect(channel, isA<num>(), reason: id);
            expect(channel as num, inInclusiveRange(0, 1), reason: id);
          }
        }
      }
    }
  });

  test('batch 2 first 40 variants have their own unpublished assets', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final batches = manifest['batches'] as List<dynamic>;
    final lot2 = (batches[1]['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(lot2.take(40).every((entry) => entry['status'] == 'draft'),
        isTrue);
    expect(lot2.skip(40).every((entry) => entry['status'] == 'draft'),
        isTrue);
    expect(lot2.where((entry) => entry['approved'] == true), isEmpty);
  });

  test('draft animations use bounded keyframes and continuous loops', () {
    for (final id in draftIds) {
      final json = jsonDecode(
          File('assets/exercise_media/lottie/$id.json').readAsStringSync())
          as Map<String, dynamic>;
      var movingElements = 0;
      for (final rawLayer in json['layers'] as List<dynamic>) {
        final layer = rawLayer as Map<String, dynamic>;
        final transform = layer['ks'] as Map<String, dynamic>;
        final position = transform['p'] as Map<String, dynamic>;
        if (position['a'] == 1) {
          final keys = position['k'] as List<dynamic>;
          expect(keys.map((k) => k['t']).toList(), [0, 30, 60, 90]);
          expect(keys[0]['s'], equals(keys[2]['s']), reason: id);
          expect(keys[2]['s'], equals(keys[3]['s']), reason: id);
          movingElements++;
        }
        for (final rawShape in _allShapes(layer['shapes'] as List<dynamic>)) {
          final shape = rawShape;
          if (shape['ty'] != 'sh') continue;
          final value = shape['ks'] as Map<String, dynamic>;
          if (value['a'] != 1) continue;
          final keys = value['k'] as List<dynamic>;
          expect(keys[0]['s'], equals(keys[2]['s']), reason: id);
          expect(keys[2]['s'], equals(keys[3]['s']), reason: id);
          movingElements++;
        }
      }
      expect(movingElements, greaterThanOrEqualTo(3), reason: id);
    }
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

  test('new vertical, unilateral and machine variants have unique media IDs', () {
    const newIds = <String>{
      'exv2_chinup',
      'exv2_glute_ham_raise',
      'exv2_chest_supported_machine_row',
      'ex_chest_flyes',
      'ex_overhead_tricep',
      'ex_db_curl',
      'ex_kelso_shrugs',
      'ex_db_shoulder_press',
      'ex_lying_leg_curl',
      'ex_bulgarian_split_squat',
    };
    expect(newIds, hasLength(10));
    expect(draftIds.containsAll(newIds), isTrue);
    for (final id in newIds) {
      final file = File('assets/exercise_media/lottie/$id.json');
      expect(file.existsSync(), isTrue, reason: id);
      final composition = jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>;
      expect(composition['nm'], contains(' / $id / '));
      expect(composition['assets'], isEmpty);
    }
  });

  test('third lot 2 group has 10 unique mobile vector compositions', () {
    const ids = <String>{
      'ex_abductor',
      'ex_adductor',
      'exv2_preacher_machine_curl',
      'exv2_smith_hip_thrust',
      'exv2_machine_crunch',
      'exv2_landmine_shoulder_press',
      'exv2_incline_machine_press',
      'exv2_hack_squat',
      'exv2_seated_calf_raise',
      'exv2_scapular_row',
    };
    expect(ids, hasLength(10));
    expect(draftIds.containsAll(ids), isTrue);
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot2 = ((manifest['batches'] as List<dynamic>)[1]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    expect(lot2.skip(20).take(10).map((entry) => entry['id']).toSet(), ids);
    final fingerprints = <String>{};
    for (final id in ids) {
      final file = File('assets/exercise_media/lottie/$id.json');
      expect(file.existsSync(), isTrue, reason: id);
      final json = jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>;
      expect(json['nm'], contains(' / $id / '));
      expect(fingerprints.add(jsonEncode(json['layers'])), isTrue,
          reason: '$id shares an entire composition');
      expect(json['assets'], isEmpty);
    }
  });

  test('fourth lot 2 group has 10 unique unloaded Lottie compositions', () {
    const ids = <String>{
      'exv2_reverse_wrist_curl',
      'exv2_cable_pullthrough',
      'exv2_assisted_pullup',
      'exv2_swiss_ball_leg_curl',
      'exv2_meadows_row',
      'ex_cable_crossover',
      'ex_dips',
      'ex_incline_db_curl',
      'ex_machine_unilateral_row',
      'ex_reverse_pec_deck',
    };
    expect(ids, hasLength(10));
    expect(draftIds.containsAll(ids), isTrue);
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot2 = ((manifest['batches'] as List<dynamic>)[1]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    expect(lot2.skip(30).take(10).map((entry) => entry['id']).toSet(), ids);
    final fingerprints = <String>{};
    for (final id in ids) {
      final file = File('assets/exercise_media/lottie/$id.json');
      expect(file.existsSync(), isTrue, reason: id);
      final composition = jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>;
      expect(composition['nm'], contains(' / $id / '));
      expect(fingerprints.add(jsonEncode(composition['layers'])), isTrue,
          reason: '$id shares a composition with another variant');
      expect(composition['assets'], isEmpty);
    }
  });

  test('lot 2 all 60 exercise variants have original draft assets', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot2 = ((manifest['batches'] as List<dynamic>)[1]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    expect(lot2, hasLength(60));
    expect(lot2.every((entry) => entry['status'] == 'draft' && entry['approved'] == false), isTrue);
    expect(draftIds.containsAll(lot2.map((entry) => entry['id'])), isTrue);
    for (final entry in lot2) {
      final file = File(entry['assetPath'] as String);
      expect(file.existsSync(), isTrue, reason: entry['id'] as String);
    }
  });

  test('lot 3 first 20 native Lottie exercise drafts are staged but unapproved', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot3 = ((manifest['batches'] as List<dynamic>)[2]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    final firstTwenty = lot3.take(20);
    expect(firstTwenty.every((entry) => entry['status'] == 'draft' &&
        entry['approved'] == false), isTrue);
    expect(lot3.skip(20).take(20).every((entry) => entry['status'] == 'draft') &&
        lot3.skip(40).every((entry) => entry['status'] == 'draft'),
        isTrue);
    expect(draftIds.containsAll(firstTwenty.map((entry) => entry['id'])),
        isTrue);
    for (final entry in firstTwenty) {
      final path = entry['assetPath'] as String;
      expect(path, startsWith('assets/exercise_media/lottie/'));
      expect(File(path).existsSync(), isTrue, reason: entry['id'] as String);
    }
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('lot 3 next 20 exercise-specific Lottie variants are drafts', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot3 = ((manifest['batches'] as List<dynamic>)[2]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    final secondTwenty = lot3.skip(20).take(20);
    expect(secondTwenty.length, 20);
    expect(secondTwenty.every((entry) =>
        entry['status'] == 'draft' && entry['approved'] == false), isTrue);
    expect(lot3.skip(40).every((entry) => entry['status'] == 'draft'), isTrue);
    expect(draftIds.containsAll(secondTwenty.map((entry) => entry['id'])),
        isTrue);
    final compositions = <String>{};
    for (final entry in secondTwenty) {
      final path = entry['assetPath'] as String;
      final json = jsonDecode(File(path).readAsStringSync())
          as Map<String, dynamic>;
      expect(json['nm'], contains(' / ${entry['id']} / '));
      expect(json['assets'], isEmpty);
      expect(compositions.add(jsonEncode(json['layers'])), isTrue,
          reason: 'A different exercise requires its own composition');
    }
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
  });

  test('lot 3 all 70 originals have Lottie drafts and remain unapproved', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final lot3 = ((manifest['batches'] as List<dynamic>)[2]['items']
        as List<dynamic>).cast<Map<String, dynamic>>();
    expect(lot3.length, 70);
    expect(lot3.every((entry) => entry['status'] == 'draft'), isTrue);
    expect(lot3.every((entry) => entry['approved'] == false), isTrue);
    expect(draftIds.containsAll(lot3.map((entry) => entry['id'])), isTrue);
    final finalThirty = lot3.skip(40);
    expect(finalThirty.length, 30);
    for (final entry in finalThirty) {
      final path = entry['assetPath'] as String;
      final json = jsonDecode(File(path).readAsStringSync())
          as Map<String, dynamic>;
      expect(json['nm'], contains(' / ${entry['id']} / '));
      expect(json['layers'], isNotEmpty);
      expect(json['assets'], isEmpty);
      expect(entry['review'], isA<Map<String, dynamic>>());
      expect((entry['review'] as Map<String, dynamic>).values,
          everyElement(isFalse));
    }
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(contains('assets/exercise_media/lottie/')));
  });

  test('first full batch is 40 drafts, never approved or bundled', () {
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final batches = manifest['batches'] as List<dynamic>;
    final batchOne = batches.first as Map<String, dynamic>;
    final items = (batchOne['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(items, hasLength(40));
    expect(items.every((item) => item['status'] == 'draft'), isTrue);
    expect(items.every((item) => item['approved'] == false), isTrue);
    expect(draftIds.containsAll(items.map((item) => item['id'])), isTrue);
    expect(ExerciseDemonstrationLibrary.approvedMedia, isEmpty);
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(contains('assets/exercise_media/lottie/')));
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
    expect(staged.length, 170);
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
