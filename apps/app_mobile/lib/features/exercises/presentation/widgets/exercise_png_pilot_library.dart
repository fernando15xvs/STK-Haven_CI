/// QA-only images: intentionally NOT in the approved media registry.
/// Visible only when compiled with --dart-define=STK_PNG_PILOTS=true.
/// Do not reuse one exercise's images for a different catalog ID.
class PngPilotStage {
  final String file;
  final String name;
  final String instruction;
  const PngPilotStage(this.file,this.name,this.instruction);
}
class PngPilotExercise {
  final String id;
  final String name;
  final List<String> primary;
  final List<String> secondary;
  final List<PngPilotStage> stages;
  const PngPilotExercise({
    required this.id,required this.name,
    required this.primary,required this.secondary,required this.stages,
  });
  String imageAt(int index) =>
      'assets/exercise_media/png_pilots/$id/${stages[index].file}.png';
}
class PngPilotLibrary {
  const PngPilotLibrary._();
  static const bool enabled=bool.fromEnvironment(
    'STK_PNG_PILOTS',defaultValue:false);
  static const Map<String,PngPilotExercise> pilots={
    'ex_bench_press':PngPilotExercise(
      id:'ex_bench_press',name:'Press de banca',
      primary:['Pectoral mayor: fibras esternocostales y claviculares'],
      secondary:['Tríceps braquial','Deltoides anterior'],
      stages:[
        PngPilotStage('01_inicio','Preparación',
          'Apoya cabeza, espalda alta y pies; sujeta la barra con muñecas alineadas.'),
        PngPilotStage('02_ejecucion','Descenso',
          'Baja la barra hacia el pecho de forma controlada, sin perder estabilidad.'),
        PngPilotStage('03_contraccion','Empuje',
          'Empuja la barra hacia arriba extendiendo los codos sin rebotes.'),
        PngPilotStage('04_retorno','Repetición',
          'Regresa a la posición inicial y mantén el control de hombros y pies.'),
      ],
    ),
    'ex_barbell_row':PngPilotExercise(
      id:'ex_barbell_row',name:'Remo con barra',
      primary:['Dorsal ancho','Romboides','Trapecio medio'],
      secondary:['Deltoides posterior','Bíceps braquial','Braquiorradial'],
      stages:[
        PngPilotStage('01_inicio','Posición inicial',
          'Inclina el torso desde la cadera, con columna estable y rodillas ligeramente flexionadas.'),
        PngPilotStage('02_ejecucion','Tirón',
          'Lleva la barra hacia el abdomen acercando los codos al tronco.'),
        PngPilotStage('03_contraccion','Final del tirón',
          'Retrae las escápulas sin sacudir el torso ni elevar excesivamente los hombros.'),
        PngPilotStage('04_retorno','Descenso',
          'Extiende los brazos con control y conserva el ángulo del tronco.'),
      ],
    ),
    'ex_squat':PngPilotExercise(
      id:'ex_squat',name:'Sentadilla con barra',
      primary:['Cuádriceps','Glúteo mayor','Aductor mayor'],
      secondary:['Erectores espinales (estabilización)',
        'Tríceps sural (estabilización)'],
      stages:[
        PngPilotStage('01_inicio','Preparación',
          'Sitúa la barra sobre la parte alta de la espalda y apoya los pies firmemente.'),
        PngPilotStage('02_ejecucion','Descenso',
          'Flexiona rodillas y caderas manteniendo los talones apoyados.'),
        PngPilotStage('03_contraccion','Posición inferior',
          'Llega a una profundidad que controles sin perder la postura lumbar.'),
        PngPilotStage('04_retorno','Ascenso',
          'Empuja el suelo y extiende caderas y rodillas sin perder estabilidad.'),
      ],
    ),
  };
  static PngPilotExercise? forId(String id) =>
      enabled?pilots[id]:null;
}
