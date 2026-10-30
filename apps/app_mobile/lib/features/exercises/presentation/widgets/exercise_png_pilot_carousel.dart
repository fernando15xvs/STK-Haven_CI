import 'package:flutter/material.dart';
import 'exercise_png_pilot_library.dart';

/// Offline-only, four transparent PNGs, no animation and no web dependence.
/// Contrasting muscle-role colors are fixed across all app accent palettes.
class ExercisePngPilotCarousel extends StatefulWidget {
  final PngPilotExercise pilot;
  final bool compact;
  const ExercisePngPilotCarousel({
    super.key,required this.pilot,this.compact=false,
  });
  @override
  State<ExercisePngPilotCarousel> createState()=>_ExercisePngPilotCarouselState();
}

class _ExercisePngPilotCarouselState extends State<ExercisePngPilotCarousel> {
  final PageController _pages=PageController();
  int _stage=0;
  static const _primaryColor=Color(0xFFEF4444);
  static const _secondaryColor=Color(0xFF2B73F6);

  @override
  void dispose() { _pages.dispose();super.dispose(); }
  void _show(int index) {
    if(index<0||index>=widget.pilot.stages.length)return;
    _pages.animateToPage(index,
        duration:const Duration(milliseconds:220),curve:Curves.easeOutCubic);
  }

  Widget _muscleGroup(BuildContext context,Color color,
      String title,List<String> muscles) => Padding(
    padding:const EdgeInsets.only(top:7),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.only(top:4),
        child:Container(width:12,height:12,decoration:BoxDecoration(
          shape:BoxShape.circle,color:color))),
      const SizedBox(width:9),
      Expanded(child:Text('$title: ${muscles.join(', ')}',
        style:Theme.of(context).textTheme.bodySmall)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme=Theme.of(context).colorScheme;
    final stages=widget.pilot.stages;
    final stage=stages[_stage];
    return Semantics(
      container:true,label:'Piloto ilustrado de ${widget.pilot.name}. '
        'Cuatro imágenes de técnica. Material experimental sin revisión profesional.',
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        ClipRRect(borderRadius:BorderRadius.circular(14),
          child:Container(
            color:colorScheme.surfaceContainerHighest,
            height:widget.compact?175:245,
            child:PageView.builder(
              key:const Key('exercise_png_pilot_pages'),
              controller:_pages,itemCount:stages.length,
              onPageChanged:(value)=>setState(()=>_stage=value),
              itemBuilder:(context,index)=>Padding(
                padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
                child:Image.asset(widget.pilot.imageAt(index),
                  key:Key('exercise_png_stage_$index'),
                  fit:BoxFit.contain,
                  semanticLabel:'${widget.pilot.name}, '
                    'paso ${index+1}: ${stages[index].name}',
                  errorBuilder:(_,_,_)=>Center(child:Text(
                    'No se pudo cargar el PNG de esta posición.',
                    textAlign:TextAlign.center,
                    style:Theme.of(context).textTheme.bodySmall)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height:7),
        Row(children:[
          IconButton(
            key:const Key('exercise_png_previous'),
            tooltip:'Paso anterior',
            onPressed:_stage==0?null:()=>_show(_stage-1),
            icon:const Icon(Icons.chevron_left)),
          Expanded(child:Text('${_stage+1} / ${stages.length} · ${stage.name}',
            key:const Key('exercise_png_stage_title'),
            style:Theme.of(context).textTheme.titleSmall,
            textAlign:TextAlign.center)),
          IconButton(
            key:const Key('exercise_png_next'),
            tooltip:'Paso siguiente',
            onPressed:_stage==stages.length-1?null:()=>_show(_stage+1),
            icon:const Icon(Icons.chevron_right)),
        ]),
        Text(stage.instruction,
          key:const Key('exercise_png_instruction'),
          style:Theme.of(context).textTheme.bodyMedium,
          textAlign:TextAlign.start),
        const SizedBox(height:8),
        _muscleGroup(context,_primaryColor,'Rojo · principales',
          widget.pilot.primary),
        _muscleGroup(context,_secondaryColor,'Azul · secundarios',
          widget.pilot.secondary),
        const SizedBox(height:6),
        Text('Ilustraciones piloto: revisa postura y músculos antes de '
          'usarlas como guía definitiva.',
          style:Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
