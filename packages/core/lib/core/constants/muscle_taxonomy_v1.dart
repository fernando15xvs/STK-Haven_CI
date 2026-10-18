/// Anatomy catalog v1. Read-only: NO changes to stored exercise names,
/// Hive records, workout snapshots, routine IDs or user preferences.
///
/// Generic categories are navigation nodes, never an additional working set.
/// Regional portions are emphasis labels, not extra independent muscles.
enum MuscleNodeType { group, muscle, region }

class MuscleNode {
  final String id;
  final String? parentId;
  final String labelEs;
  final String anatomicalName;
  final MuscleNodeType type;
  final List<String> aliases;
  /// Additional browsing locations without duplicating the canonical ID.
  final List<String> crossListedUnder;

  const MuscleNode({
    required this.id,
    required this.parentId,
    required this.labelEs,
    required this.anatomicalName,
    required this.type,
    this.aliases = const [],
    this.crossListedUnder = const [],
  });

  bool get isCategory => type == MuscleNodeType.group;
  bool get isRegionalEmphasis => type == MuscleNodeType.region;
  /// Regions and categories must never multiply the parent exercise's sets.
  bool get isIndependentMuscle => type == MuscleNodeType.muscle;
}

enum LegacyMuscleResolutionStatus {
  exact,
  byExerciseContext,
  ambiguous,
  unknown,
}

class LegacyMuscleResolution {
  final LegacyMuscleResolutionStatus status;
  final String originalLabel;
  /// May be a general group for an ambiguous historical label.
  final String? nodeId;
  /// Candidate IDs are only *suggestions*, never automatic allocations.
  final List<String> candidateIds;

  const LegacyMuscleResolution({
    required this.status,
    required this.originalLabel,
    this.nodeId,
    this.candidateIds = const [],
  });

  bool get isSpecific =>
      status == LegacyMuscleResolutionStatus.exact ||
      status == LegacyMuscleResolutionStatus.byExerciseContext;
}

class MuscleTaxonomyV1 {
  const MuscleTaxonomyV1._();
  static const String version = 'muscle_taxonomy_v1';

  static final List<MuscleNode> nodes = List.unmodifiable([
    MuscleNode(id: 'mg_upper_body', parentId: null, labelEs: 'Tren superior', anatomicalName: 'Upper body', type: MuscleNodeType.group, aliases: ['tren superior', 'upper body'], crossListedUnder: const []),
    MuscleNode(id: 'mg_chest', parentId: 'mg_upper_body', labelEs: 'Pecho', anatomicalName: 'Pectoral region', type: MuscleNodeType.group, aliases: ['pecho', 'pectorales', 'chest'], crossListedUnder: const []),
    MuscleNode(id: 'm_pectoralis_major', parentId: 'mg_chest', labelEs: 'Pectoral mayor', anatomicalName: 'Pectoralis major', type: MuscleNodeType.muscle, aliases: ['pectoral mayor', 'pectoralis major'], crossListedUnder: const []),
    MuscleNode(id: 'reg_pec_clavicular', parentId: 'm_pectoralis_major', labelEs: 'Pectoral superior · porción clavicular', anatomicalName: 'Clavicular head of pectoralis major', type: MuscleNodeType.region, aliases: ['pecho superior', 'pectoral superior', 'porcion clavicular'], crossListedUnder: const []),
    MuscleNode(id: 'reg_pec_esternocostal', parentId: 'm_pectoralis_major', labelEs: 'Pectoral medio · porción esternocostal', anatomicalName: 'Sternocostal head of pectoralis major', type: MuscleNodeType.region, aliases: ['pecho medio', 'pectoral medio', 'porcion esternocostal'], crossListedUnder: const []),
    MuscleNode(id: 'reg_pec_inferior', parentId: 'm_pectoralis_major', labelEs: 'Pectoral inferior · énfasis de fibras inferiores', anatomicalName: 'Inferior sternocostal/abdominal fibers of pectoralis major', type: MuscleNodeType.region, aliases: ['pecho inferior', 'pectoral inferior'], crossListedUnder: const []),
    MuscleNode(id: 'm_pectoralis_minor', parentId: 'mg_chest', labelEs: 'Pectoral menor', anatomicalName: 'Pectoralis minor', type: MuscleNodeType.muscle, aliases: ['pectoral menor', 'pectoralis minor'], crossListedUnder: const []),
    MuscleNode(id: 'mg_shoulder_girdle', parentId: 'mg_upper_body', labelEs: 'Cintura escapular', anatomicalName: 'Shoulder girdle', type: MuscleNodeType.group, aliases: ['cintura escapular', 'escapula'], crossListedUnder: const []),
    MuscleNode(id: 'm_serratus_anterior', parentId: 'mg_shoulder_girdle', labelEs: 'Serrato anterior', anatomicalName: 'Serratus anterior', type: MuscleNodeType.muscle, aliases: ['serrato', 'serratos', 'serrato anterior', 'serratus anterior'], crossListedUnder: ['mg_core']),
    MuscleNode(id: 'mg_shoulders', parentId: 'mg_upper_body', labelEs: 'Hombros', anatomicalName: 'Shoulder muscles', type: MuscleNodeType.group, aliases: ['hombros', 'hombro', 'shoulders', 'shoulder'], crossListedUnder: const []),
    MuscleNode(id: 'm_deltoid', parentId: 'mg_shoulders', labelEs: 'Deltoides · sin porción especificada', anatomicalName: 'Deltoid', type: MuscleNodeType.muscle, aliases: ['deltoides', 'deltoide', 'deltoid'], crossListedUnder: const []),
    MuscleNode(id: 'reg_deltoid_anterior', parentId: 'm_deltoid', labelEs: 'Deltoides anterior', anatomicalName: 'Anterior deltoid', type: MuscleNodeType.region, aliases: ['hombro anterior', 'deltoide anterior', 'deltoides anteriores', 'front delt'], crossListedUnder: const []),
    MuscleNode(id: 'reg_deltoid_lateral', parentId: 'm_deltoid', labelEs: 'Deltoides lateral', anatomicalName: 'Middle deltoid', type: MuscleNodeType.region, aliases: ['hombro lateral', 'deltoide lateral', 'deltoides medio', 'deltoides lateral', 'side delt'], crossListedUnder: const []),
    MuscleNode(id: 'reg_deltoid_posterior', parentId: 'm_deltoid', labelEs: 'Deltoides posterior', anatomicalName: 'Posterior deltoid', type: MuscleNodeType.region, aliases: ['hombro posterior', 'hombros posteriores', 'deltoide posterior', 'deltoides posteriores', 'rear delt'], crossListedUnder: const []),
    MuscleNode(id: 'mg_rotator_cuff', parentId: 'mg_shoulders', labelEs: 'Manguito rotador', anatomicalName: 'Rotator cuff', type: MuscleNodeType.group, aliases: ['manguito rotador', 'rotator cuff'], crossListedUnder: const []),
    MuscleNode(id: 'm_supraspinatus', parentId: 'mg_rotator_cuff', labelEs: 'Supraespinoso', anatomicalName: 'Supraspinatus', type: MuscleNodeType.muscle, aliases: ['supraespinoso'], crossListedUnder: const []),
    MuscleNode(id: 'm_infraspinatus', parentId: 'mg_rotator_cuff', labelEs: 'Infraespinoso', anatomicalName: 'Infraspinatus', type: MuscleNodeType.muscle, aliases: ['infraespinoso'], crossListedUnder: const []),
    MuscleNode(id: 'm_teres_minor', parentId: 'mg_rotator_cuff', labelEs: 'Redondo menor', anatomicalName: 'Teres minor', type: MuscleNodeType.muscle, aliases: ['redondo menor'], crossListedUnder: const []),
    MuscleNode(id: 'm_subscapularis', parentId: 'mg_rotator_cuff', labelEs: 'Subescapular', anatomicalName: 'Subscapularis', type: MuscleNodeType.muscle, aliases: ['subescapular'], crossListedUnder: const []),
    MuscleNode(id: 'm_teres_major', parentId: 'mg_shoulders', labelEs: 'Redondo mayor', anatomicalName: 'Teres major', type: MuscleNodeType.muscle, aliases: ['redondo mayor'], crossListedUnder: const []),
    MuscleNode(id: 'mg_back', parentId: 'mg_upper_body', labelEs: 'Espalda', anatomicalName: 'Back', type: MuscleNodeType.group, aliases: ['espalda', 'back'], crossListedUnder: const []),
    MuscleNode(id: 'm_latissimus_dorsi', parentId: 'mg_back', labelEs: 'Dorsal ancho', anatomicalName: 'Latissimus dorsi', type: MuscleNodeType.muscle, aliases: ['dorsal', 'dorsales', 'dorsal ancho', 'latissimus dorsi', 'lats'], crossListedUnder: const []),
    MuscleNode(id: 'mg_rhomboids', parentId: 'mg_back', labelEs: 'Romboides', anatomicalName: 'Rhomboid muscles', type: MuscleNodeType.group, aliases: ['romboides', 'rhomboids'], crossListedUnder: const []),
    MuscleNode(id: 'm_rhomboid_major', parentId: 'mg_rhomboids', labelEs: 'Romboides mayor', anatomicalName: 'Rhomboid major', type: MuscleNodeType.muscle, aliases: ['romboides mayor', 'rhomboid major'], crossListedUnder: const []),
    MuscleNode(id: 'm_rhomboid_minor', parentId: 'mg_rhomboids', labelEs: 'Romboides menor', anatomicalName: 'Rhomboid minor', type: MuscleNodeType.muscle, aliases: ['romboides menor', 'rhomboid minor'], crossListedUnder: const []),
    MuscleNode(id: 'mg_trapezius', parentId: 'mg_back', labelEs: 'Trapecios', anatomicalName: 'Trapezius', type: MuscleNodeType.group, aliases: ['trapecio', 'trapecios', 'traps'], crossListedUnder: const []),
    MuscleNode(id: 'reg_trapezius_upper', parentId: 'mg_trapezius', labelEs: 'Trapecio superior', anatomicalName: 'Upper trapezius', type: MuscleNodeType.region, aliases: ['trapecio superior', 'upper traps'], crossListedUnder: const []),
    MuscleNode(id: 'reg_trapezius_middle', parentId: 'mg_trapezius', labelEs: 'Trapecio medio', anatomicalName: 'Middle trapezius', type: MuscleNodeType.region, aliases: ['trapecio medio'], crossListedUnder: const []),
    MuscleNode(id: 'reg_trapezius_lower', parentId: 'mg_trapezius', labelEs: 'Trapecio inferior', anatomicalName: 'Lower trapezius', type: MuscleNodeType.region, aliases: ['trapecio inferior'], crossListedUnder: const []),
    MuscleNode(id: 'm_levator_scapulae', parentId: 'mg_back', labelEs: 'Elevador de la escápula', anatomicalName: 'Levator scapulae', type: MuscleNodeType.muscle, aliases: ['elevador de la escapula'], crossListedUnder: const []),
    MuscleNode(id: 'mg_spinal_stabilizers', parentId: 'mg_back', labelEs: 'Zona lumbar y estabilizadores', anatomicalName: 'Posterior spinal muscles', type: MuscleNodeType.group, aliases: ['espalda baja', 'lumbar', 'lumbares'], crossListedUnder: const []),
    MuscleNode(id: 'm_erector_spinae', parentId: 'mg_spinal_stabilizers', labelEs: 'Erectores espinales', anatomicalName: 'Erector spinae', type: MuscleNodeType.muscle, aliases: ['erectores', 'erectores espinales', 'erector spinae'], crossListedUnder: ['mg_core']),
    MuscleNode(id: 'm_multifidus', parentId: 'mg_spinal_stabilizers', labelEs: 'Multífidos', anatomicalName: 'Multifidus', type: MuscleNodeType.muscle, aliases: ['multifidos', 'multifidus'], crossListedUnder: ['mg_core']),
    MuscleNode(id: 'm_quadratus_lumborum', parentId: 'mg_spinal_stabilizers', labelEs: 'Cuadrado lumbar', anatomicalName: 'Quadratus lumborum', type: MuscleNodeType.muscle, aliases: ['cuadrado lumbar'], crossListedUnder: ['mg_core']),
    MuscleNode(id: 'mg_arms', parentId: 'mg_upper_body', labelEs: 'Brazos', anatomicalName: 'Arms', type: MuscleNodeType.group, aliases: ['brazo', 'brazos', 'arms'], crossListedUnder: const []),
    MuscleNode(id: 'mg_biceps', parentId: 'mg_arms', labelEs: 'Bíceps', anatomicalName: 'Biceps', type: MuscleNodeType.group, aliases: ['biceps', 'bíceps', 'musculos del biceps'], crossListedUnder: const []),
    MuscleNode(id: 'm_biceps_brachii', parentId: 'mg_biceps', labelEs: 'Bíceps braquial · general', anatomicalName: 'Biceps brachii', type: MuscleNodeType.muscle, aliases: ['biceps braquial'], crossListedUnder: const []),
    MuscleNode(id: 'reg_biceps_long_head', parentId: 'm_biceps_brachii', labelEs: 'Bíceps · cabeza larga', anatomicalName: 'Long head of biceps brachii', type: MuscleNodeType.region, aliases: ['biceps cabeza larga', 'cabeza larga del biceps'], crossListedUnder: const []),
    MuscleNode(id: 'reg_biceps_short_head', parentId: 'm_biceps_brachii', labelEs: 'Bíceps · cabeza corta', anatomicalName: 'Short head of biceps brachii', type: MuscleNodeType.region, aliases: ['biceps cabeza corta', 'cabeza corta del biceps'], crossListedUnder: const []),
    MuscleNode(id: 'm_brachialis', parentId: 'mg_biceps', labelEs: 'Braquial anterior', anatomicalName: 'Brachialis', type: MuscleNodeType.muscle, aliases: ['braquial', 'braquial anterior'], crossListedUnder: const []),
    MuscleNode(id: 'm_brachioradialis', parentId: 'mg_biceps', labelEs: 'Braquiorradial', anatomicalName: 'Brachioradialis', type: MuscleNodeType.muscle, aliases: ['braquiorradial', 'braquioradial'], crossListedUnder: const []),
    MuscleNode(id: 'mg_triceps', parentId: 'mg_arms', labelEs: 'Tríceps', anatomicalName: 'Triceps', type: MuscleNodeType.group, aliases: ['triceps', 'tríceps'], crossListedUnder: const []),
    MuscleNode(id: 'm_triceps_brachii', parentId: 'mg_triceps', labelEs: 'Tríceps braquial · general', anatomicalName: 'Triceps brachii', type: MuscleNodeType.muscle, aliases: ['triceps braquial'], crossListedUnder: const []),
    MuscleNode(id: 'reg_triceps_long_head', parentId: 'm_triceps_brachii', labelEs: 'Tríceps · cabeza larga', anatomicalName: 'Long head of triceps brachii', type: MuscleNodeType.region, aliases: ['triceps cabeza larga'], crossListedUnder: const []),
    MuscleNode(id: 'reg_triceps_lateral_head', parentId: 'm_triceps_brachii', labelEs: 'Tríceps · cabeza lateral', anatomicalName: 'Lateral head of triceps brachii', type: MuscleNodeType.region, aliases: ['triceps cabeza lateral'], crossListedUnder: const []),
    MuscleNode(id: 'reg_triceps_medial_head', parentId: 'm_triceps_brachii', labelEs: 'Tríceps · cabeza medial', anatomicalName: 'Medial head of triceps brachii', type: MuscleNodeType.region, aliases: ['triceps cabeza medial'], crossListedUnder: const []),
    MuscleNode(id: 'mg_forearms', parentId: 'mg_arms', labelEs: 'Antebrazos', anatomicalName: 'Forearms', type: MuscleNodeType.group, aliases: ['antebrazo', 'antebrazos', 'forearms'], crossListedUnder: const []),
    MuscleNode(id: 'mg_forearm_flexors', parentId: 'mg_forearms', labelEs: 'Flexores y pronadores del antebrazo', anatomicalName: 'Forearm flexors and pronators', type: MuscleNodeType.group, aliases: ['flexores de antebrazo', 'pronadores'], crossListedUnder: const []),
    MuscleNode(id: 'mg_forearm_extensors', parentId: 'mg_forearms', labelEs: 'Extensores y supinadores del antebrazo', anatomicalName: 'Forearm extensors and supinators', type: MuscleNodeType.group, aliases: ['extensores de antebrazo', 'supinadores'], crossListedUnder: const []),
    MuscleNode(id: 'mg_lower_body', parentId: null, labelEs: 'Tren inferior', anatomicalName: 'Lower body', type: MuscleNodeType.group, aliases: ['piernas', 'pierna', 'tren inferior', 'lower body'], crossListedUnder: const []),
    MuscleNode(id: 'mg_hips', parentId: 'mg_lower_body', labelEs: 'Cadera', anatomicalName: 'Hip', type: MuscleNodeType.group, aliases: ['cadera', 'hip'], crossListedUnder: const []),
    MuscleNode(id: 'mg_glutes', parentId: 'mg_hips', labelEs: 'Glúteos', anatomicalName: 'Gluteals', type: MuscleNodeType.group, aliases: ['gluteos', 'glúteos', 'glutes'], crossListedUnder: const []),
    MuscleNode(id: 'm_gluteus_maximus', parentId: 'mg_glutes', labelEs: 'Glúteo mayor', anatomicalName: 'Gluteus maximus', type: MuscleNodeType.muscle, aliases: ['gluteo mayor', 'gluteus maximus'], crossListedUnder: const []),
    MuscleNode(id: 'm_gluteus_medius', parentId: 'mg_glutes', labelEs: 'Glúteo medio', anatomicalName: 'Gluteus medius', type: MuscleNodeType.muscle, aliases: ['gluteo medio', 'gluteus medius'], crossListedUnder: const []),
    MuscleNode(id: 'm_gluteus_minimus', parentId: 'mg_glutes', labelEs: 'Glúteo menor', anatomicalName: 'Gluteus minimus', type: MuscleNodeType.muscle, aliases: ['gluteo menor', 'gluteus minimus'], crossListedUnder: const []),
    MuscleNode(id: 'm_tensor_fasciae_latae', parentId: 'mg_hips', labelEs: 'Tensor de la fascia lata', anatomicalName: 'Tensor fasciae latae', type: MuscleNodeType.muscle, aliases: ['tensor de fascia lata', 'tfl'], crossListedUnder: const []),
    MuscleNode(id: 'mg_adductors', parentId: 'mg_hips', labelEs: 'Aductores de cadera', anatomicalName: 'Hip adductors', type: MuscleNodeType.group, aliases: ['aductores', 'aductor'], crossListedUnder: const []),
    MuscleNode(id: 'm_adductor_magnus', parentId: 'mg_adductors', labelEs: 'Aductor mayor', anatomicalName: 'Adductor magnus', type: MuscleNodeType.muscle, aliases: ['aductor mayor'], crossListedUnder: const []),
    MuscleNode(id: 'm_adductor_longus', parentId: 'mg_adductors', labelEs: 'Aductor largo', anatomicalName: 'Adductor longus', type: MuscleNodeType.muscle, aliases: ['aductor largo'], crossListedUnder: const []),
    MuscleNode(id: 'm_adductor_brevis', parentId: 'mg_adductors', labelEs: 'Aductor corto', anatomicalName: 'Adductor brevis', type: MuscleNodeType.muscle, aliases: ['aductor corto'], crossListedUnder: const []),
    MuscleNode(id: 'm_gracilis', parentId: 'mg_adductors', labelEs: 'Grácil', anatomicalName: 'Gracilis', type: MuscleNodeType.muscle, aliases: ['gracil', 'recto interno'], crossListedUnder: const []),
    MuscleNode(id: 'm_pectineus', parentId: 'mg_adductors', labelEs: 'Pectíneo', anatomicalName: 'Pectineus', type: MuscleNodeType.muscle, aliases: ['pectineo'], crossListedUnder: const []),
    MuscleNode(id: 'm_iliopsoas', parentId: 'mg_hips', labelEs: 'Iliopsoas', anatomicalName: 'Iliopsoas', type: MuscleNodeType.muscle, aliases: ['iliopsoas', 'iliaco', 'psoas'], crossListedUnder: const []),
    MuscleNode(id: 'mg_deep_hip_rotators', parentId: 'mg_hips', labelEs: 'Rotadores profundos de cadera', anatomicalName: 'Deep hip rotators', type: MuscleNodeType.group, aliases: ['rotadores profundos', 'piriforme'], crossListedUnder: const []),
    MuscleNode(id: 'mg_thighs', parentId: 'mg_lower_body', labelEs: 'Muslos', anatomicalName: 'Thighs', type: MuscleNodeType.group, aliases: ['muslos', 'thigh'], crossListedUnder: const []),
    MuscleNode(id: 'mg_quadriceps', parentId: 'mg_thighs', labelEs: 'Cuádriceps', anatomicalName: 'Quadriceps femoris', type: MuscleNodeType.group, aliases: ['cuadriceps', 'cuádriceps', 'quads'], crossListedUnder: const []),
    MuscleNode(id: 'm_rectus_femoris', parentId: 'mg_quadriceps', labelEs: 'Recto femoral', anatomicalName: 'Rectus femoris', type: MuscleNodeType.muscle, aliases: ['recto femoral'], crossListedUnder: const []),
    MuscleNode(id: 'm_vastus_lateralis', parentId: 'mg_quadriceps', labelEs: 'Vasto lateral', anatomicalName: 'Vastus lateralis', type: MuscleNodeType.muscle, aliases: ['vasto lateral'], crossListedUnder: const []),
    MuscleNode(id: 'm_vastus_medialis', parentId: 'mg_quadriceps', labelEs: 'Vasto medial', anatomicalName: 'Vastus medialis', type: MuscleNodeType.muscle, aliases: ['vasto medial'], crossListedUnder: const []),
    MuscleNode(id: 'm_vastus_intermedius', parentId: 'mg_quadriceps', labelEs: 'Vasto intermedio', anatomicalName: 'Vastus intermedius', type: MuscleNodeType.muscle, aliases: ['vasto intermedio'], crossListedUnder: const []),
    MuscleNode(id: 'mg_hamstrings', parentId: 'mg_thighs', labelEs: 'Isquiotibiales', anatomicalName: 'Hamstrings', type: MuscleNodeType.group, aliases: ['isquios', 'isquiosurales', 'isquiotibiales', 'femorales', 'hamstrings'], crossListedUnder: const []),
    MuscleNode(id: 'm_biceps_femoris', parentId: 'mg_hamstrings', labelEs: 'Bíceps femoral', anatomicalName: 'Biceps femoris', type: MuscleNodeType.muscle, aliases: ['biceps femoral'], crossListedUnder: const []),
    MuscleNode(id: 'reg_biceps_femoris_long', parentId: 'm_biceps_femoris', labelEs: 'Bíceps femoral · cabeza larga', anatomicalName: 'Long head of biceps femoris', type: MuscleNodeType.region, aliases: ['biceps femoral cabeza larga'], crossListedUnder: const []),
    MuscleNode(id: 'reg_biceps_femoris_short', parentId: 'm_biceps_femoris', labelEs: 'Bíceps femoral · cabeza corta', anatomicalName: 'Short head of biceps femoris', type: MuscleNodeType.region, aliases: ['biceps femoral cabeza corta'], crossListedUnder: const []),
    MuscleNode(id: 'm_semitendinosus', parentId: 'mg_hamstrings', labelEs: 'Semitendinoso', anatomicalName: 'Semitendinosus', type: MuscleNodeType.muscle, aliases: ['semitendinoso'], crossListedUnder: const []),
    MuscleNode(id: 'm_semimembranosus', parentId: 'mg_hamstrings', labelEs: 'Semimembranoso', anatomicalName: 'Semimembranosus', type: MuscleNodeType.muscle, aliases: ['semimembranoso'], crossListedUnder: const []),
    MuscleNode(id: 'm_sartorius', parentId: 'mg_thighs', labelEs: 'Sartorio', anatomicalName: 'Sartorius', type: MuscleNodeType.muscle, aliases: ['sartorio'], crossListedUnder: const []),
    MuscleNode(id: 'mg_lower_leg', parentId: 'mg_lower_body', labelEs: 'Pierna inferior', anatomicalName: 'Lower leg', type: MuscleNodeType.group, aliases: ['pierna inferior', 'gemelos', 'pantorrillas', 'pantorrilla'], crossListedUnder: const []),
    MuscleNode(id: 'mg_calf', parentId: 'mg_lower_leg', labelEs: 'Tríceps sural', anatomicalName: 'Triceps surae', type: MuscleNodeType.group, aliases: ['triceps sural', 'calves'], crossListedUnder: const []),
    MuscleNode(id: 'm_gastrocnemius', parentId: 'mg_calf', labelEs: 'Gastrocnemio', anatomicalName: 'Gastrocnemius', type: MuscleNodeType.muscle, aliases: ['gastrocnemio', 'gemelo'], crossListedUnder: const []),
    MuscleNode(id: 'reg_gastrocnemius_medial', parentId: 'm_gastrocnemius', labelEs: 'Gastrocnemio medial', anatomicalName: 'Medial head of gastrocnemius', type: MuscleNodeType.region, aliases: ['gemelo medial', 'gastrocnemio medial'], crossListedUnder: const []),
    MuscleNode(id: 'reg_gastrocnemius_lateral', parentId: 'm_gastrocnemius', labelEs: 'Gastrocnemio lateral', anatomicalName: 'Lateral head of gastrocnemius', type: MuscleNodeType.region, aliases: ['gemelo lateral', 'gastrocnemio lateral'], crossListedUnder: const []),
    MuscleNode(id: 'm_soleus', parentId: 'mg_calf', labelEs: 'Sóleo', anatomicalName: 'Soleus', type: MuscleNodeType.muscle, aliases: ['soleo'], crossListedUnder: const []),
    MuscleNode(id: 'm_tibialis_anterior', parentId: 'mg_lower_leg', labelEs: 'Tibial anterior', anatomicalName: 'Tibialis anterior', type: MuscleNodeType.muscle, aliases: ['tibial anterior'], crossListedUnder: const []),
    MuscleNode(id: 'mg_fibularis', parentId: 'mg_lower_leg', labelEs: 'Peroneos o fibulares', anatomicalName: 'Fibularis muscles', type: MuscleNodeType.group, aliases: ['peroneos', 'fibulares'], crossListedUnder: const []),
    MuscleNode(id: 'mg_deep_calf_flexors', parentId: 'mg_lower_leg', labelEs: 'Flexores profundos de pierna y dedos', anatomicalName: 'Deep posterior leg flexors', type: MuscleNodeType.group, aliases: ['flexores profundos'], crossListedUnder: const []),
    MuscleNode(id: 'mg_foot_intrinsics', parentId: 'mg_lower_leg', labelEs: 'Musculatura intrínseca del pie', anatomicalName: 'Intrinsic foot muscles', type: MuscleNodeType.group, aliases: ['intrinsecos del pie'], crossListedUnder: const []),
    MuscleNode(id: 'mg_core', parentId: null, labelEs: 'Complejo abdominal y estabilización', anatomicalName: 'Core and abdominal wall', type: MuscleNodeType.group, aliases: ['core', 'tronco', 'zona media'], crossListedUnder: const []),
    MuscleNode(id: 'mg_abdominals', parentId: 'mg_core', labelEs: 'Abdomen', anatomicalName: 'Abdominal wall', type: MuscleNodeType.group, aliases: ['abdomen', 'abdominales', 'pared abdominal'], crossListedUnder: const []),
    MuscleNode(id: 'm_rectus_abdominis', parentId: 'mg_abdominals', labelEs: 'Recto abdominal', anatomicalName: 'Rectus abdominis', type: MuscleNodeType.muscle, aliases: ['recto abdominal', 'six pack'], crossListedUnder: const []),
    MuscleNode(id: 'reg_rectus_abdominis_upper', parentId: 'm_rectus_abdominis', labelEs: 'Recto abdominal · énfasis superior', anatomicalName: 'Upper rectus abdominis region', type: MuscleNodeType.region, aliases: ['abdomen superior', 'abdominal superior'], crossListedUnder: const []),
    MuscleNode(id: 'reg_rectus_abdominis_lower', parentId: 'm_rectus_abdominis', labelEs: 'Recto abdominal · énfasis inferior', anatomicalName: 'Lower rectus abdominis region', type: MuscleNodeType.region, aliases: ['abdomen inferior', 'abdominal inferior'], crossListedUnder: const []),
    MuscleNode(id: 'mg_obliques', parentId: 'mg_abdominals', labelEs: 'Oblicuos', anatomicalName: 'Abdominal obliques', type: MuscleNodeType.group, aliases: ['oblicuos', 'oblicuo'], crossListedUnder: const []),
    MuscleNode(id: 'm_external_oblique', parentId: 'mg_obliques', labelEs: 'Oblicuo externo', anatomicalName: 'External abdominal oblique', type: MuscleNodeType.muscle, aliases: ['oblicuo externo', 'obliquo externo'], crossListedUnder: const []),
    MuscleNode(id: 'm_internal_oblique', parentId: 'mg_obliques', labelEs: 'Oblicuo interno', anatomicalName: 'Internal abdominal oblique', type: MuscleNodeType.muscle, aliases: ['oblicuo interno', 'obliquo interno'], crossListedUnder: const []),
    MuscleNode(id: 'm_transversus_abdominis', parentId: 'mg_abdominals', labelEs: 'Transverso del abdomen', anatomicalName: 'Transversus abdominis', type: MuscleNodeType.muscle, aliases: ['transverso', 'transverso abdominal'], crossListedUnder: const []),
    MuscleNode(id: 'm_diaphragm', parentId: 'mg_core', labelEs: 'Diafragma · respiración', anatomicalName: 'Diaphragm', type: MuscleNodeType.muscle, aliases: ['diafragma'], crossListedUnder: const []),
    MuscleNode(id: 'mg_pelvic_floor', parentId: 'mg_core', labelEs: 'Suelo pélvico', anatomicalName: 'Pelvic floor', type: MuscleNodeType.group, aliases: ['suelo pelvico', 'pelvic floor'], crossListedUnder: const []),
  ]);

  static final Map<String, MuscleNode> byId =
      Map.unmodifiable({for (final item in nodes) item.id: item});

  static String normalize(String raw) {
    final s = raw.trim().toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n');
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static final Map<String, List<String>> _aliasIds = () {
    final map = <String, Set<String>>{};
    for (final node in nodes) {
      for (final name in [node.id, node.labelEs, node.anatomicalName,
            ...node.aliases]) {
        final key = normalize(name);
        if (key.isEmpty) continue;
        map.putIfAbsent(key, () => <String>{}).add(node.id);
      }
    }
    return Map.unmodifiable({
      for (final entry in map.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }();

  /// Lookup is deliberately conservative. A historical `Piernas`,
  /// `Hombros` or `Abdomen` cannot specify a single anatomical muscle.
  /// `verifiedTargetId` is allowed ONLY after explicit user review of an
  /// exercise's exact movement, not inferred from the historical group name.
  static LegacyMuscleResolution resolveLegacy(String label,
      {String? verifiedTargetId}) {
    final key = normalize(label);
    if (key.isEmpty) {
      return LegacyMuscleResolution(
          status: LegacyMuscleResolutionStatus.unknown,
          originalLabel: label);
    }
    if (key == 'triceps y hombro' || key == 'triceps y hombros') {
      return LegacyMuscleResolution(
        status: LegacyMuscleResolutionStatus.ambiguous,
        originalLabel: label,
        candidateIds: const ['mg_triceps', 'mg_shoulders'],
      );
    }
    if (key == 'gluteos y isquios' || key == 'gluteos e isquios' ||
        key == 'gluteos e isquiotibiales') {
      return LegacyMuscleResolution(
        status: LegacyMuscleResolutionStatus.ambiguous,
        originalLabel: label,
        candidateIds: const ['mg_glutes', 'mg_hamstrings'],
      );
    }
    final matches = _aliasIds[key] ?? const <String>[];
    if (matches.isEmpty) {
      return LegacyMuscleResolution(
          status: LegacyMuscleResolutionStatus.unknown,
          originalLabel: label);
    }
    final reviewed = byId[verifiedTargetId];
    if (reviewed != null && !reviewed.isCategory &&
        matches.any((id) => id == reviewed.id || belongsToGroup(reviewed.id, id))) {
      return LegacyMuscleResolution(
        status: LegacyMuscleResolutionStatus.byExerciseContext,
        originalLabel: label,
        nodeId: reviewed.id,
        candidateIds: matches,
      );
    }
    if (matches.length == 1 && byId[matches.single]?.isCategory == false) {
      return LegacyMuscleResolution(
          status: LegacyMuscleResolutionStatus.exact,
          originalLabel: label,
          nodeId: matches.single);
    }
    return LegacyMuscleResolution(
        status: LegacyMuscleResolutionStatus.ambiguous,
        originalLabel: label,
        nodeId: matches.length == 1 ? matches.single : null,
        candidateIds: matches);
  }

  static bool belongsToGroup(String nodeId, String groupId) {
    if (nodeId == groupId) return true;
    final visited = <String>{};
    final todo = <String>[nodeId];
    while (todo.isNotEmpty) {
      final current = todo.removeLast();
      if (!visited.add(current)) continue;
      final node = byId[current];
      if (node == null) continue;
      for (final parent in [if (node.parentId != null) node.parentId!,
            ...node.crossListedUnder]) {
        if (parent == groupId) return true;
        todo.add(parent);
      }
    }
    return false;
  }

  /// Distinct IDs support cross-listed muscles (e.g. multifidus/core and
  /// back) without duplicate category rows or duplicate set attribution.
  static List<MuscleNode> descendantsOf(String groupId,
      {bool includeRegions = true}) =>
      List.unmodifiable(nodes.where((node) =>
          node.id != groupId && belongsToGroup(node.id, groupId) &&
          (includeRegions || !node.isRegionalEmphasis)));

  static List<MuscleNode> search(String query,
      {bool includeCategories = true}) {
    final needle = normalize(query);
    if (needle.isEmpty) return const [];
    final direct = nodes.where((node) =>
        [node.id, node.labelEs, node.anatomicalName, ...node.aliases]
            .any((name) => normalize(name).contains(needle))).toList();
    final matchingGroups = direct.where((node) => node.isCategory)
        .map((node) => node.id).toSet();
    return List.unmodifiable(nodes.where((node) =>
        (includeCategories || !node.isCategory) &&
        (direct.contains(node) ||
          matchingGroups.any((id) => belongsToGroup(node.id, id)))));
  }
}
