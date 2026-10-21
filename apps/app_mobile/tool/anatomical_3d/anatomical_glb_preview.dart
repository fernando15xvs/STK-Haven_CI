import 'dart:typed_data';
import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'anatomical_glb_runtime.dart';
import 'anatomical_glb_staging.dart';

/// Isolated GLB candidate viewer. CPU skinning, drawVertices rasterization.
/// It must NOT be routed from the production exercise catalogue yet.
class AnatomicalGlbPreview extends StatefulWidget {
  const AnatomicalGlbPreview({
    super.key,required this.scene,this.progress,this.dimension=360,
    this.highlightRegions=const <String>{},
  });
  final GlbSkinnedScene scene;
  final double? progress;
  final double dimension;
  /// Exercise-specific muscles for offline preview. No production routing.
  final Set<String> highlightRegions;
  static GlbSkinnedScene decode(Uint8List bytes) => GlbSkinnedScene.decode(bytes);
  @override
  State<AnatomicalGlbPreview> createState()=>_AnatomicalGlbPreviewState();
}

class _AnatomicalGlbPreviewState extends State<AnatomicalGlbPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock=AnimationController(
    vsync:this,duration:Duration(milliseconds:
        (widget.scene.durationSeconds*1000).round()));
  bool _playing=true;
  double _orbit=0;
  String? _cacheKey;
  GlbDrawFrame? _cached;
  @override
  void initState(){super.initState();_clock.repeat();}
  @override
  void didChangeDependencies(){super.didChangeDependencies();_sync();}
  @override
  void didUpdateWidget(covariant AnatomicalGlbPreview oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.scene!=widget.scene){
      _clock.duration=Duration(milliseconds:
          (widget.scene.durationSeconds*1000).round());
    }
    _cacheKey=null;
    _sync();
  }
  void _sync(){
    if(widget.progress!=null||MediaQuery.disableAnimationsOf(context)||!_playing){
      _clock.stop();
      if(widget.progress!=null||MediaQuery.disableAnimationsOf(context)){
        _clock.value=widget.progress?.clamp(0.0,1.0)??.35;
      }
    }else if(!_clock.isAnimating){
      _clock.repeat();
    }
  }
  @override
  void dispose(){_clock.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    final palette=AppColors.of(context);
    final dark=Theme.of(context).brightness==Brightness.dark;
    final materials=AnatomicalGlbStaging.themeMasterRegions(context,
        highlightedRegions:widget.highlightRegions);
    return Column(mainAxisSize:MainAxisSize.min,children:[
      Semantics(
        label:widget.scene.id+
          '. Modelo 3D experimental animado, pendiente de aprobación.',
        image:true,
        child:GestureDetector(
          onHorizontalDragUpdate:(details)=>setState((){
            _orbit=(_orbit+details.delta.dx*.006).clamp(-.8,.8);
            _cacheKey=null;
          }),
          child:RepaintBoundary(
            key:const Key('skinned_glb_canvas'),
            child:SizedBox(width:widget.dimension,height:widget.dimension,
              child:AnimatedBuilder(animation:_clock,builder:(context,_){
                // 24 Hz model update; Flutter composites the cached triangles.
                final p=widget.progress??_clock.value;
                final tick=(p*widget.scene.durationSeconds*24).floor();
                // Extra depth ordering only for paused/static QA frames.
                // Animated preview keeps the original low-draw-call path.
                final still=widget.progress!=null||
                    MediaQuery.disableAnimationsOf(context)||!_playing;
                final depthSlices=still?6:1;
                final regions=widget.highlightRegions.toList()..sort();
                final key=[tick,depthSlices,_orbit,regions.join(','),
                  palette.primary.toARGB32(),
                  palette.surface.toARGB32(),widget.dimension,dark,
                  widget.scene.id].join(':');
                if(_cached==null||_cacheKey!=key){
                  _cached=widget.scene.frame(tick/24,
                    Size(widget.dimension,widget.dimension),materials,
                    dark:dark,orbit:_orbit,depthSlices:depthSlices);
                  _cacheKey=key;
                }
                return CustomPaint(painter:GlbSkinnedPainter(
                  _cached!,palette.surface));
              }),
            ),
          ),
        ),
      ),
      if(widget.progress==null&&!MediaQuery.disableAnimationsOf(context))
        TextButton(key:const Key('skinned_glb_play_pause'),
          onPressed:()=>setState((){
            _playing=!_playing;_sync();
          }),
          child:Text(_playing?'Pausar':'Reproducir')),
    ]);
  }
}
