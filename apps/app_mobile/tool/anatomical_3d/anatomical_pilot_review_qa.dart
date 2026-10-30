// Review contract only. NEVER a biomechanical approval or automatic gate.
// Three pilot exercises precede scaling the unapproved CC0 master to 229.
import 'anatomical_glb_staging.dart';

class AnatomicalPilotQaPlan {
  const AnatomicalPilotQaPlan({
    required this.exerciseId,required this.title,
    required this.equipment,required this.primaryRegions,
    required this.secondaryRegions,required this.checks,
  });

  final String exerciseId,title,equipment;
  final Set<String> primaryRegions,secondaryRegions;
  final List<String> checks;

  /// Neither a completed test nor a release decision: always false until a
  /// qualified human signs off on the specific GLB, device and exercise.
  bool get isApproved => false;
  bool get isEnabled => false;

  bool get hasValidRegions =>
      primaryRegions.isNotEmpty&&
      primaryRegions.intersection(secondaryRegions).isEmpty&&
      AnatomicalGlbStaging.masterRegionNames
        .containsAll(primaryRegions.union(secondaryRegions));

  Map<String,Object> toReviewJson() => {
    'exerciseId':exerciseId,
    'title':title,
    'equipment':equipment,
    'primaryRegions':primaryRegions.toList()..sort(),
    'secondaryRegions':secondaryRegions.toList()..sort(),
    'manualChecks':checks,
    'automatedBiomechanicsApproval':false,
    'physicalDeviceReviewed':false,
    'anatomicalExpertReviewed':false,
    'approved':false,
    'enabled':false,
  };

  static const cases=<String,AnatomicalPilotQaPlan>{
    'ex_bench_press':AnatomicalPilotQaPlan(
      exerciseId:'ex_bench_press',
      title:'Press de banca con barra',
      equipment:'Banco, barra y discos',
      primaryRegions:{'pectoralis_major','anterior_deltoid','triceps_brachii'},
      secondaryRegions:{'rhomboids'},
      checks:[
        'Banco y barra visibles con dimensiones y eje de agarre correctos',
        'Cabeza, escápulas, glúteos y pies mantienen contacto y estabilidad',
        'Muñecas alineadas con codos y agarre sin penetración de la barra',
        'La barra describe un recorrido verificable sin atravesar el tórax',
        'Rango inferior/superior, respiración y trayectorias aprobadas por coach',
      ],
    ),
    'ex_barbell_row':AnatomicalPilotQaPlan(
      exerciseId:'ex_barbell_row',
      title:'Remo con barra',
      equipment:'Barra, discos y suelo',
      primaryRegions:{
        'latissimus_dorsi','rhomboids','middle_trapezius',
        'posterior_deltoid',
      },
      secondaryRegions:{'hamstrings'},
      checks:[
        'Agarre bilateral estable de la barra durante toda la trayectoria',
        'Columna y bisagra de cadera coherentes sin movimiento espurio',
        'Barra se aproxima al tronco sin atravesar cadera o rodillas',
        'Escápulas se mueven naturalmente y hombros mantienen simetría',
        'Posición de pies y carga verificadas por entrenador',
      ],
    ),
    'ex_squat':AnatomicalPilotQaPlan(
      exerciseId:'ex_squat',
      title:'Sentadilla con barra',
      equipment:'Barra, discos y suelo',
      primaryRegions:{
        'quadriceps_femoris','gluteus_maximus','adductor_magnus',
      },
      secondaryRegions:{'hamstrings'},
      checks:[
        'Ambos pies permanecen plantados y sin deslizamientos sobre suelo',
        'Rodillas siguen dirección del pie durante descenso y ascenso',
        'Pelvis, tronco y columna con desplazamiento articular plausible',
        'Barra apoya en trapecio con manos alineadas sin penetrar el cuerpo',
        'Profundidad, equilibrio y fase excéntrica/concéntrica validados',
      ],
    ),
  };
}
