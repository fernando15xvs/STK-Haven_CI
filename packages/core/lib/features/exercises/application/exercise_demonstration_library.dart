import 'package:core/domain/models/exercise.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';

/// Exercise-specific steps are editorial guidance, not individualized advice.
class ExerciseTechniqueGuide {
  final String setup;
  final String movement;
  final String safety;

  const ExerciseTechniqueGuide({
    required this.setup,
    required this.movement,
    required this.safety,
  });
}

/// Media may only be shown after exercise-level movement and usage rights
/// are documented. A valid source URL alone is NOT a commercial license.
enum ExerciseMediaFormat { gif, poster }

class VerifiedExerciseMedia {
  final String exerciseId;
  final String assetPath;
  final ExerciseMediaFormat format;
  final String copyrightHolder;
  final String distributionPermission;
  final String attribution;

  const VerifiedExerciseMedia({
    required this.exerciseId,
    required this.assetPath,
    required this.format,
    required this.copyrightHolder,
    required this.distributionPermission,
    required this.attribution,
  });
}

class ExerciseDemonstrationLibrary {
  const ExerciseDemonstrationLibrary._();

  /// No third-party files will be shipped on the assumption that public
  /// download implies license. Add only reviewed, exercise-specific assets.
  static const Map<String, VerifiedExerciseMedia> approvedMedia = {};

  static VerifiedExerciseMedia? mediaFor(Exercise exercise) {
    final verified = approvedMedia[exercise.id];
    if (verified == null ||
        verified.exerciseId != exercise.id ||
        verified.assetPath.isEmpty ||
        !verified.assetPath.startsWith('assets/exercise_media/') ||
        verified.distributionPermission.trim().isEmpty ||
        verified.copyrightHolder.trim().isEmpty ||
        verified.attribution.trim().isEmpty) {
      return null;
    }
    return verified;
  }

  static ExerciseTechniqueGuide? guideFor(Exercise exercise) {
    final explicit = _guides[exercise.id];
    if (explicit != null) return explicit;
    final definition = CuratedExerciseCatalog.byId[exercise.id];
    if (definition != null) {
      return ExerciseTechniqueGuide(
        setup: 'Prepara el equipo: ${definition.equipment}. '
            'Ajusta una postura estable y un rango sin dolor.',
        movement: definition.technique,
        safety: 'Evita que ${definition.commonMistake}. '
            'Reduce la carga si pierdes el control.',
      );
    }
    // Keep the 49 original presets' stored wording where a full editorial
    // guide has not yet been written. No biomechanical specificity is inferred
    // from a broad category such as "Piernas" or "Espalda".
    if (CuratedExerciseCatalog.legacyProfiles.containsKey(exercise.id) &&
        exercise.instructions.trim().isNotEmpty) {
      return ExerciseTechniqueGuide(
        setup: 'Comprueba que el equipo esté estable y utiliza una carga '
            'que puedas controlar.',
        movement: exercise.instructions.trim(),
        safety: 'Realiza el recorrido sin dolor ni movimientos bruscos.',
      );
    }
    // For user-created exercises, preserve their authored text; never
    // invent a technique based solely on a generic muscle tag.
    return null;
  }

  static const Map<String, ExerciseTechniqueGuide> _guides = {
    'ex_bench_press': ExerciseTechniqueGuide(setup: 'Apoya cabeza, espalda alta y pies con estabilidad; coloca ojos bajo la barra.', movement: 'Baja la barra al pecho con antebrazos cercanos a vertical y empuja de forma controlada.', safety: 'Evita rebotar la barra o perder el apoyo de los pies.'),
    'ex_incline_db_press': ExerciseTechniqueGuide(setup: 'Ajusta el banco inclinado a un ángulo cómodo y apoya ambos pies.', movement: 'Desciende las mancuernas al costado del pecho superior y elévalas sin chocarlas.', safety: 'Evita arquear en exceso la zona lumbar.'),
    'ex_lat_pulldown': ExerciseTechniqueGuide(setup: 'Ajusta el apoyo de muslos y sitúa las manos en agarre cómodo.', movement: 'Lleva los codos hacia abajo y la barra delante del rostro hacia el pecho.', safety: 'No tires la barra detrás del cuello ni balances el tronco.'),
    'ex_pullups': ExerciseTechniqueGuide(setup: 'Usa barra segura y toma un agarre que permita hombros cómodos.', movement: 'Asciende llevando codos hacia costillas y desciende sin dejarte caer.', safety: 'Evita impulso excesivo y rangos dolorosos de hombro.'),
    'ex_barbell_row': ExerciseTechniqueGuide(setup: 'Sitúa pies estables y flexiona caderas para inclinar el torso.', movement: 'Acerca la barra hacia el tronco manteniendo la espalda estable.', safety: 'Evita levantar el pecho a tirones en cada repetición.'),
    'ex_cable_row': ExerciseTechniqueGuide(setup: 'Coloca pies y espalda estables; comienza con brazos extendidos cómodamente.', movement: 'Lleva los codos hacia atrás y regresa sin colapsar el tronco.', safety: 'No conviertas el remo en un balanceo.'),
    'ex_ohp': ExerciseTechniqueGuide(setup: 'Asegura un agarre cómodo y estabiliza el abdomen.', movement: 'Empuja la barra por encima de la cabeza con recorrido controlado.', safety: 'Evita inclinar excesivamente la espalda.'),
    'ex_lateral_raises': ExerciseTechniqueGuide(setup: 'Sostén mancuernas con codos suavemente flexionados.', movement: 'Eleva brazos hacia los lados dentro de un rango sin dolor.', safety: 'Evita encoger hombros y usar impulso.'),
    'ex_rdl': ExerciseTechniqueGuide(setup: 'Sitúa la carga cerca de muslos, pies estables y rodillas algo flexionadas.', movement: 'Lleva la cadera hacia atrás manteniendo la carga cerca de las piernas.', safety: 'No fuerces profundidad perdiendo la postura lumbar.'),
    'ex_squat': ExerciseTechniqueGuide(setup: 'Ajusta una postura cómoda y verifica soportes antes de cargar.', movement: 'Flexiona rodillas y caderas a la profundidad que controles y asciende.', safety: 'Evita que el talón se eleve o colapsar el tronco.'),
    'ex_leg_press': ExerciseTechniqueGuide(setup: 'Ajusta el asiento y coloca ambos pies firmes sobre la plataforma.', movement: 'Flexiona rodillas hasta un rango seguro y extiende sin bloquear bruscamente.', safety: 'No despegues la pelvis del respaldo.'),
    'ex_leg_extension': ExerciseTechniqueGuide(setup: 'Alinea las rodillas con el eje de la máquina y ajusta rodillos.', movement: 'Extiende las piernas con control y desciende sin dejar caer el peso.', safety: 'Evita golpes en el tope de recorrido.'),
    'ex_leg_curl': ExerciseTechniqueGuide(setup: 'Ajusta rodillas y almohadilla a tu longitud de piernas.', movement: 'Flexiona las rodillas suavemente y vuelve sin dejar caer la carga.', safety: 'Evita mover la cadera o arquear la espalda.'),
    'ex_hip_thrust': ExerciseTechniqueGuide(setup: 'Apoya espalda alta en un banco firme y coloca los pies estables.', movement: 'Eleva la cadera hasta extenderla, manteniendo costillas controladas.', safety: 'Evita hiperextender la zona lumbar arriba.'),
    'ex_calf_raise': ExerciseTechniqueGuide(setup: 'Sitúa puntas en plataforma estable y sujétate si hace falta.', movement: 'Eleva y baja los talones de forma gradual.', safety: 'Evita rebotes rápidos al final del descenso.'),
    'ex_crunch': ExerciseTechniqueGuide(setup: 'Túmbate y coloca cuello en posición cómoda.', movement: 'Acerca las costillas a la pelvis elevando suavemente la parte alta del tronco.', safety: 'No tires del cuello con las manos.'),
    'ex_barbell_curl': ExerciseTechniqueGuide(setup: 'Sujeta la barra con agarre cómodo y codos cerca del tronco.', movement: 'Flexiona los codos y baja la barra de manera gradual.', safety: 'No balances la cintura.'),
    'ex_hammer_curl': ExerciseTechniqueGuide(setup: 'Sostén mancuernas con pulgares mirando hacia arriba.', movement: 'Flexiona el codo manteniendo la muñeca neutra y desciende lento.', safety: 'Evita girar la muñeca para compensar.'),
    'ex_tricep_pushdown': ExerciseTechniqueGuide(setup: 'Coloca codos cerca de las costillas y hombros relajados.', movement: 'Extiende los codos hacia abajo y deja regresar el cable con control.', safety: 'Evita separar los codos o inclinar todo el cuerpo.'),
    'ex_face_pull': ExerciseTechniqueGuide(setup: 'Coloca la cuerda aproximadamente a la altura del rostro.', movement: 'Tira hacia cara alta separando extremos de la cuerda con control.', safety: 'No tires del cuello ni arquees la espalda.'),
    'exv2_flat_db_press': ExerciseTechniqueGuide(setup: 'Acuéstate con pies estables, escápulas controladas y mancuernas sobre el pecho.', movement: 'Baja las cargas en un arco cómodo y empuja sin golpearlas.', safety: 'No rebotes en la parte inferior ni pierdas control de muñecas.'),
    'exv2_incline_barbell_press': ExerciseTechniqueGuide(setup: 'Coloca banco con inclinación moderada y usa soportes o asistente.', movement: 'Baja hacia pecho superior y vuelve extendiendo codos con control.', safety: 'Evita descensos bruscos o exceso de inclinación.'),
    'exv2_single_arm_pulldown': ExerciseTechniqueGuide(setup: 'Arrodíllate junto a la polea y estabiliza el tronco.', movement: 'Tira del codo hacia la cadera sin girar el pecho.', safety: 'Evita balancear torso para completar repeticiones.'),
    'exv2_chest_supported_db_row': ExerciseTechniqueGuide(setup: 'Ajusta banco inclinado y apoya completamente el pecho.', movement: 'Lleva codos hacia atrás y baja mancuernas lentamente.', safety: 'No despegues el pecho del banco.'),
    'exv2_single_arm_db_row': ExerciseTechniqueGuide(setup: 'Apoya mano y rodilla o mano y pie de modo seguro.', movement: 'Lleva el codo hacia la cadera manteniendo pelvis quieta.', safety: 'Evita girar el tronco para elevar más peso.'),
    'exv2_arnold_press': ExerciseTechniqueGuide(setup: 'Siéntate con respaldo y sujeta mancuernas cerca de hombros.', movement: 'Eleva las mancuernas realizando una rotación gradual y cómoda.', safety: 'Evita compensar con arco lumbar.'),
    'exv2_seated_db_lateral_raise': ExerciseTechniqueGuide(setup: 'Siéntate firme con brazos junto al torso y codos suaves.', movement: 'Eleva los brazos hacia los lados hasta un rango cómodo.', safety: 'No balances tronco ni eleves hombros.'),
    'exv2_single_arm_rear_cable_fly': ExerciseTechniqueGuide(setup: 'Coloca polea aproximadamente a la altura de hombros y apóyate.', movement: 'Abre el brazo hacia atrás sin rotar el tronco.', safety: 'Evita convertirlo en remo doblando mucho el codo.'),
    'exv2_ez_bar_curl': ExerciseTechniqueGuide(setup: 'Toma barra EZ por una posición de muñecas cómoda.', movement: 'Eleva la barra flexionando los codos y baja sin impulso.', safety: 'No adelantes todo el hombro para subirla.'),
    'exv2_rope_pushdown': ExerciseTechniqueGuide(setup: 'Sujeta cuerda con codos junto al torso.', movement: 'Extiende los codos y separa levemente extremos abajo.', safety: 'No flexiones el tronco para aumentar peso.'),
    'exv2_front_squat': ExerciseTechniqueGuide(setup: 'Ajusta agarre frontal, columna estable y talones firmes.', movement: 'Desciende flexionando cadera y rodilla y asciende manteniendo tronco firme.', safety: 'No sacrifiques postura por ganar profundidad.'),
    'exv2_goblet_squat': ExerciseTechniqueGuide(setup: 'Sostén pesa cerca del esternón y abre los pies cómodamente.', movement: 'Siéntate entre caderas y asciende presionando el suelo.', safety: 'Evita que la carga te incline hacia delante.'),
    'exv2_db_rdl': ExerciseTechniqueGuide(setup: 'Coloca mancuernas cerca de piernas y rodillas algo flexionadas.', movement: 'Lleva cadera atrás manteniendo cargas próximas y vuelve extendiendo cadera.', safety: 'No redondees la espalda buscando llegar más abajo.'),
    'exv2_nordic_curl': ExerciseTechniqueGuide(setup: 'Fija tobillos con soporte seguro y acolcha las rodillas.', movement: 'Desciende lentamente con tronco y cadera alineados; ayúdate al subir.', safety: 'Evita caer de golpe o forzar una repetición sin asistencia.'),
    'exv2_machine_hip_thrust': ExerciseTechniqueGuide(setup: 'Ajusta cinturón y respaldo de la máquina según tu cuerpo.', movement: 'Empuja con los pies para elevar cadera hasta extensión cómoda.', safety: 'Evita elevar costillas al final.'),
    'exv2_cable_hip_abduction': ExerciseTechniqueGuide(setup: 'Ancla el cable a un tobillo y estabiliza pelvis con apoyo.', movement: 'Separa lentamente la pierna hacia el lateral.', safety: 'No inclines el tronco para ganar amplitud.'),
    'exv2_seated_calf_raise': ExerciseTechniqueGuide(setup: 'Coloca almohadillas sobre muslos y pies en la plataforma.', movement: 'Eleva y baja los talones con rodillas flexionadas.', safety: 'Evita rebotar en el estiramiento.'),
    'exv2_cable_crunch': ExerciseTechniqueGuide(setup: 'Arrodíllate con cuerda cerca de sienes y pelvis estable.', movement: 'Acerca costillas hacia pelvis flexionando el tronco sin tirar con brazos.', safety: 'No conviertas el movimiento en una flexión de cadera.'),
    'exv2_reverse_crunch': ExerciseTechniqueGuide(setup: 'Túmbate boca arriba y coloca manos para estabilizarte.', movement: 'Lleva la pelvis suavemente hacia las costillas con piernas flexionadas.', safety: 'No balancees las piernas ni despegues hombros de golpe.'),
    'exv2_pallof_press': ExerciseTechniqueGuide(setup: 'Sitúate de lado a una polea y mantén pies firmes.', movement: 'Extiende las manos al frente resistiendo la rotación del cable.', safety: 'Evita permitir que el torso gire.'),
    'exv2_side_plank': ExerciseTechniqueGuide(setup: 'Apoya antebrazo debajo del hombro y alinea cadera con tronco.', movement: 'Mantén postura con respiración fluida y control.', safety: 'No dejes caer la pelvis ni bloquees el aire.'),
    'exv2_scapular_pushup': ExerciseTechniqueGuide(setup: 'Colócate en plancha con manos bajo hombros y codos extendidos.', movement: 'Separa y acerca suavemente las escápulas sin doblar brazos.', safety: 'No hundas la zona lumbar.'),
    'exv2_sumo_deadlift': ExerciseTechniqueGuide(setup: 'Coloca pies amplios en una postura cómoda y barra sobre mediopié.', movement: 'Empuja el suelo elevando cadera y pecho de forma coordinada.', safety: 'Evita despegar la barra con tirón lumbar.'),
  };
}
