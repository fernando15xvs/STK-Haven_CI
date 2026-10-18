import 'package:core/core/constants/muscle_taxonomy_v1.dart';

/// Read-only canonical aggregation of historic labels. It is NOT a migration
/// of Hive/SQL rows, workout snapshots, backups or PRs.
class CanonicalMuscleProjection {
  final String key;
  final String label;
  final String originalLabel;
  final String? anatomyId;
  final String? reportGroupId;
  final LegacyMuscleResolutionStatus status;

  const CanonicalMuscleProjection({
    required this.key,
    required this.label,
    required this.originalLabel,
    required this.anatomyId,
    required this.reportGroupId,
    required this.status,
  });

  bool get requiresReview =>
      status == LegacyMuscleResolutionStatus.ambiguous ||
      status == LegacyMuscleResolutionStatus.unknown;

  bool get isSpecific =>
      status == LegacyMuscleResolutionStatus.exact ||
      status == LegacyMuscleResolutionStatus.byExerciseContext;
}

/// Projects ONE primary exercise label into ONE reporting category. Parent and
/// child group rows never multiply a recorded set. An anatomical portion does
/// not mean that all of a set's stimulus belongs exclusively to that portion.
class CanonicalMuscleProjector {
  const CanonicalMuscleProjector._();

  static const Map<String, String> _labels = {
    'mg_chest': 'Pecho',
    'mg_shoulders': 'Hombros',
    'mg_shoulder_girdle': 'Cintura escapular',
    'mg_rotator_cuff': 'Manguito rotador',
    'mg_rhomboids': 'Romboides',
    'mg_trapezius': 'Trapecios',
    'mg_back': 'Espalda',
    'mg_biceps': 'Bíceps',
    'mg_triceps': 'Tríceps',
    'mg_forearms': 'Antebrazos',
    'mg_arms': 'Brazos',
    'mg_glutes': 'Glúteos',
    'mg_adductors': 'Aductores',
    'mg_hips': 'Cadera',
    'mg_quadriceps': 'Cuádriceps',
    'mg_hamstrings': 'Isquiotibiales',
    'mg_thighs': 'Muslos',
    'mg_calf': 'Pantorrillas',
    'mg_lower_leg': 'Pierna inferior',
    'mg_obliques': 'Oblicuos',
    'mg_abdominals': 'Abdomen',
    'mg_core': 'Core',
    'mg_upper_body': 'Tren superior',
    'mg_lower_body': 'Piernas',
  };

  // Ordered from specific reporting categories to broad parents, following
  // CANONICAL ancestry only (never cross-listing), to avoid double attribution.
  static const _priority = [
    'mg_chest', 'mg_rotator_cuff', 'mg_shoulders', 'mg_shoulder_girdle',
    'mg_rhomboids', 'mg_trapezius', 'mg_back', 'mg_biceps',
    'mg_triceps', 'mg_forearms', 'mg_arms',
    'mg_glutes', 'mg_adductors', 'mg_quadriceps', 'mg_hamstrings',
    'mg_calf', 'mg_lower_leg', 'mg_hips', 'mg_thighs',
    'mg_obliques', 'mg_abdominals', 'mg_core',
    'mg_upper_body', 'mg_lower_body',
  ];

  static CanonicalMuscleProjection? resolve(String label) {
    final original = label.trim();
    if (original.isEmpty) return null;
    final resolved = MuscleTaxonomyV1.resolveLegacy(original);
    final nodeId = resolved.nodeId;
    // A known category may be ambiguous as to WHICH muscle but still safe
    // as a reporting group. Compounds remain unresolved.
    String? groupId;
    if (nodeId != null && MuscleTaxonomyV1.byId.containsKey(nodeId)) {
      final ancestors = <String>{};
      String? current = nodeId;
      while (current != null && ancestors.add(current)) {
        current = MuscleTaxonomyV1.byId[current]?.parentId;
      }
      for (final candidate in _priority) {
        if (ancestors.contains(candidate)) {
          groupId = candidate;
          break;
        }
      }
    }
    if (groupId != null) {
      return CanonicalMuscleProjection(
        key: groupId,
        label: _labels[groupId] ?? MuscleTaxonomyV1.byId[groupId]!.labelEs,
        originalLabel: original,
        anatomyId: nodeId,
        reportGroupId: groupId,
        status: resolved.status,
      );
    }
    // Unknown, ambiguous compound, or non-canonical label:
    // preserve a distinct, reviewable legacy bucket. Never infer anatomy.
    final normalized = MuscleTaxonomyV1.normalize(original);
    return CanonicalMuscleProjection(
      key: 'legacy:$normalized',
      label: original,
      originalLabel: original,
      anatomyId: null,
      reportGroupId: null,
      status: resolved.status,
    );
  }
}
