import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/core/constants/preset_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('taxonomy IDs, aliases, ancestry and cross-listing are well formed', () {
    final ids = MuscleTaxonomyV1.nodes.map((n) => n.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.length, greaterThanOrEqualTo(90));
    for (final node in MuscleTaxonomyV1.nodes) {
      expect(node.labelEs.trim(), isNotEmpty);
      expect(node.anatomicalName.trim(), isNotEmpty);
      expect(node.id, matches(RegExp(r'^(mg|m|reg)_[a-z0-9_]+$')));
      if (node.parentId != null) {
        expect(MuscleTaxonomyV1.byId.containsKey(node.parentId), true,
            reason: node.id);
        expect(MuscleTaxonomyV1.belongsToGroup(node.id, node.parentId!),
            isTrue, reason: node.id);
      }
      expect(MuscleTaxonomyV1.belongsToGroup(node.id, 'not_a_group'), false);
      for (final extra in node.crossListedUnder) {
        expect(MuscleTaxonomyV1.byId[extra]?.isCategory, isTrue);
      }
    }
    expect(MuscleTaxonomyV1.version, 'muscle_taxonomy_v1');
    expect(MuscleTaxonomyV1.nodes.where(
        (e) => e.type == MuscleNodeType.region).length, greaterThan(10));
  });

  test('all 49 legacy preset primary and secondary labels resolve safely', () {
    expect(presetExercises, hasLength(49));
    for (final exercise in presetExercises) {
      for (final label in [exercise.muscleGroup, ...exercise.secondaryMuscles]) {
        final resolved = MuscleTaxonomyV1.resolveLegacy(label);
        expect(resolved.status, isNot(LegacyMuscleResolutionStatus.unknown),
            reason: '${exercise.id} · $label');
      }
    }
    expect(
      MuscleTaxonomyV1.resolveLegacy('Hombros').status,
      LegacyMuscleResolutionStatus.ambiguous,
    );
    expect(
      MuscleTaxonomyV1.resolveLegacy('Piernas').nodeId,
      'mg_lower_body',
    );
    expect(
      MuscleTaxonomyV1.resolveLegacy('Espalda').nodeId,
      'mg_back',
    );
    expect(
      MuscleTaxonomyV1.resolveLegacy('Dorsal').nodeId,
      'm_latissimus_dorsi',
    );
  });

  test('shoulder regions are specific; broad shoulder is NOT anterior', () {
    expect(MuscleTaxonomyV1.resolveLegacy('Hombro').isSpecific, false);
    expect(MuscleTaxonomyV1.resolveLegacy('HOMBROS').nodeId, 'mg_shoulders');
    expect(MuscleTaxonomyV1.resolveLegacy('hombro anterior').nodeId,
        'reg_deltoid_anterior');
    expect(MuscleTaxonomyV1.resolveLegacy('Deltoide LATERAL').nodeId,
        'reg_deltoid_lateral');
    expect(MuscleTaxonomyV1.resolveLegacy('Hombros posteriores').nodeId,
        'reg_deltoid_posterior');
    expect(MuscleTaxonomyV1.resolveLegacy('Deltoides').nodeId,
        'm_deltoid');
    final reviewed = MuscleTaxonomyV1.resolveLegacy(
      'Hombros', verifiedTargetId: 'reg_deltoid_posterior',
    );
    expect(reviewed.status, LegacyMuscleResolutionStatus.byExerciseContext);
    expect(reviewed.nodeId, 'reg_deltoid_posterior');
    // An unrelated ID must not be accepted as contextual classification.
    expect(MuscleTaxonomyV1.resolveLegacy('Hombros',
        verifiedTargetId: 'm_rectus_femoris').status,
        LegacyMuscleResolutionStatus.ambiguous);
  });

  test('pectoral portions, obliques, serratus, quadriceps and hamstrings', () {
    final expected = <String, String>{
      'pectoral superior': 'reg_pec_clavicular',
      'Pecho medio': 'reg_pec_esternocostal',
      'pecho inferior': 'reg_pec_inferior',
      'oblicuo externo': 'm_external_oblique',
      'oblicuo interno': 'm_internal_oblique',
      'transverso': 'm_transversus_abdominis',
      'abdomen superior': 'reg_rectus_abdominis_upper',
      'abdomen inferior': 'reg_rectus_abdominis_lower',
      'serratos': 'm_serratus_anterior',
      'romboides mayor': 'm_rhomboid_major',
      'romboides menor': 'm_rhomboid_minor',
      'vasto intermedio': 'm_vastus_intermedius',
      'recto femoral': 'm_rectus_femoris',
      'biceps femoral cabeza corta': 'reg_biceps_femoris_short',
      'semitendinoso': 'm_semitendinosus',
      'gluteo medio': 'm_gluteus_medius',
      'gastrocnemio medial': 'reg_gastrocnemius_medial',
      'soleo': 'm_soleus',
    };
    for (final entry in expected.entries) {
      final actual = MuscleTaxonomyV1.resolveLegacy(entry.key);
      expect(actual.status, LegacyMuscleResolutionStatus.exact,
          reason: entry.key);
      expect(actual.nodeId, entry.value, reason: entry.key);
    }
    expect(
      MuscleTaxonomyV1.resolveLegacy('Oblicuos').isSpecific, false);
    expect(
      MuscleTaxonomyV1.resolveLegacy('Abdomen').nodeId, 'mg_abdominals');
  });

  test('categories are noncountable and portions do not multiply sets', () {
    expect(MuscleTaxonomyV1.byId['mg_chest']!.isIndependentMuscle, false);
    expect(MuscleTaxonomyV1.byId['reg_pec_clavicular']!
        .isIndependentMuscle, false);
    expect(MuscleTaxonomyV1.byId['m_pectoralis_major']!
        .isIndependentMuscle, true);
    expect(MuscleTaxonomyV1.byId['reg_deltoid_anterior']!
        .isRegionalEmphasis, true);
    final lower = MuscleTaxonomyV1.descendantsOf('mg_lower_body');
    expect(lower.map((n) => n.id), containsAll([
      'm_gluteus_maximus', 'm_rectus_femoris',
      'm_semitendinosus', 'm_soleus',
    ]));
    expect(lower.map((n) => n.id).toSet().length, lower.length);
    final core = MuscleTaxonomyV1.descendantsOf('mg_core');
    expect(core.map((n) => n.id), containsAll([
      'm_rectus_abdominis', 'm_external_oblique', 'm_internal_oblique',
      'm_transversus_abdominis', 'm_multifidus', 'm_serratus_anterior',
    ]));
    expect(core.map((n) => n.id).toSet().length, core.length);
    expect(MuscleTaxonomyV1.descendantsOf('mg_chest',
        includeRegions: false).every((n) => !n.isRegionalEmphasis), isTrue);
  });

  test('combined labels and unknown names remain unresolved, without edits', () {
    for (final input in [
      'Tríceps y hombro', 'glúteos e isquios', 'glúteos y isquios',
    ]) {
      final resolved = MuscleTaxonomyV1.resolveLegacy(input);
      expect(resolved.isSpecific, false);
      expect(resolved.status, LegacyMuscleResolutionStatus.ambiguous);
      expect(resolved.nodeId, isNull);
      expect(resolved.candidateIds, hasLength(2));
      // Original is retained verbatim for a safe, later review.
      expect(resolved.originalLabel, input);
    }
    for (final input in ['músculo que no existe', '', '🦾']) {
      expect(MuscleTaxonomyV1.resolveLegacy(input).status,
          LegacyMuscleResolutionStatus.unknown);
    }
    expect(MuscleTaxonomyV1.resolveLegacy('Hombro').originalLabel, 'Hombro');
  });

  test('accent-insensitive search returns anatomical descendants only once', () {
    expect(MuscleTaxonomyV1.normalize('  CÚADRÍCEPS '), 'cuadriceps');
    final hamstrings = MuscleTaxonomyV1.search('isquios');
    expect(hamstrings.map((e) => e.id), contains('m_semitendinosus'));
    final core = MuscleTaxonomyV1.search('oblicuos',
        includeCategories: false);
    expect(core.map((e) => e.id), containsAll([
      'm_external_oblique', 'm_internal_oblique',
    ]));
    expect(core.every((e) => !e.isCategory), isTrue);
    expect(MuscleTaxonomyV1.search('serrato').map((e) => e.id),
        contains('m_serratus_anterior'));
    expect(MuscleTaxonomyV1.search('').length, 0);
  });

  test('catalog is read-only; all legacy exercise IDs and labels remain', () {
    final original = [
      for (final e in presetExercises)
        (e.id, e.muscleGroup, [...e.secondaryMuscles])
    ];
    for (final exercise in presetExercises) {
      MuscleTaxonomyV1.resolveLegacy(exercise.muscleGroup);
      for (final secondary in exercise.secondaryMuscles) {
        MuscleTaxonomyV1.resolveLegacy(secondary);
      }
    }
    expect([
      for (final e in presetExercises)
        (e.id, e.muscleGroup, [...e.secondaryMuscles])
    ].map((record) => record.toString()).toList(),
    original.map((record) => record.toString()).toList());
  });
}
