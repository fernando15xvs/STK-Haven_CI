import 'dart:typed_data';
import 'package:core/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'anatomical_glb_runtime.dart';
import 'native_gpu_glb_review.dart';
import 'native_gpu_skinning_review.dart';
import 'anatomical_glb_camera.dart';
import 'anatomical_glb_staging.dart';

/// Isolated GLB candidate viewer. CPU skinning, drawVertices rasterization.
/// It must NOT be routed from the production exercise catalogue yet.
class AnatomicalGlbPreview extends StatefulWidget {
  const AnatomicalGlbPreview({
    super.key,required this.scene,this.progress,this.dimension=360,
    this.highlightRegions=const <String>{},
    this.experimentalNativeGpuStatic=false,
    this.experimentalGpuSkinning=false,
    this.experimentalGpuMorphs=false,
  });
  final GlbSkinnedScene scene;
  final double? progress;
  final double dimension;
  /// Exercise-specific muscles for offline preview. No production routing.
  final Set<String> highlightRegions;
  /// Never enabled by production: only static, paused or reduced-motion QA.
  /// Renders native Metal/GLES triangles with depth while CPU skinning stays.
  final bool experimentalNativeGpuStatic;
  /// Separate GLES3/Metal shader skinning QA, disabled in production.
  final bool experimentalGpuSkinning;
  /// v9.3 experimental reusable base mesh + 8 GPU morph targets;
  /// only sampled poses, never continuous or routed to the exercise list.
  final bool experimentalGpuMorphs;
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
  GlbCameraPose _camera=const GlbCameraPose();
  double _pinchStartZoom=1;
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
          onScaleStart:(_)=>_pinchStartZoom=_camera.zoom,
          onScaleUpdate:(details)=>setState((){
            _camera=details.pointerCount>1
              ?_camera.scale(details.scale,initialZoom:_pinchStartZoom)
              :_camera.drag(details.focalPointDelta.dx,
                            details.focalPointDelta.dy);
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
                final key=[tick,depthSlices,_camera.yaw,
                  _camera.elevation,_camera.zoom,regions.join(','),
                  palette.primary.toARGB32(),
                  palette.surface.toARGB32(),widget.dimension,dark,
                  widget.scene.id].join(':');
                if(_cached==null||_cacheKey!=key){
                  _cached=widget.scene.frame(tick/24,
                    Size(widget.dimension,widget.dimension),materials,
                    dark:dark,orbit:_camera.yaw,
                    elevation:_camera.elevation,zoom:_camera.zoom,
                    depthSlices:depthSlices,poseNormals:still);
                  _cacheKey=key;
                }
                if((widget.experimentalGpuSkinning||
                    widget.experimentalGpuMorphs)&&still) {
                  return NativeGpuSkinnedGlbReview(
                    scene:widget.scene,size:widget.dimension,
                    materials:materials,background:palette.surface,
                    elapsed:tick/24,dark:dark,orbit:_camera.yaw,
                    elevation:_camera.elevation,zoom:_camera.zoom,
                    enabled:true,
                    experimentalMorphGpu:widget.experimentalGpuMorphs,
                  );
                }
                if(widget.experimentalNativeGpuStatic&&still) {
                  return NativeGpuGlbReview(
                    scene:widget.scene,size:widget.dimension,
                    materials:materials,background:palette.surface,
                    elapsed:tick/24,dark:dark,orbit:_camera.yaw,
                    elevation:_camera.elevation,zoom:_camera.zoom,
                    enabled:true,
                  );
                }
                return CustomPaint(painter:GlbSkinnedPainter(
                  _cached!,palette.surface));
              }),
            ),
          ),
        ),
      ),
      Row(mainAxisSize:MainAxisSize.min,children:[
        if(widget.progress==null&&!MediaQuery.disableAnimationsOf(context))
          TextButton(key:const Key('skinned_glb_play_pause'),
            onPressed:()=>setState((){
              _playing=!_playing;_sync();
            }),
            child:Text(_playing?'Pausar':'Reproducir')),
        IconButton(key:const Key('skinned_glb_zoom_in'),
          tooltip:'Acercar modelo 3D',icon:const Icon(Icons.zoom_in),
          onPressed:()=>setState((){
            _camera=_camera.zoomButton(true);_cacheKey=null;
          })),
        IconButton(key:const Key('skinned_glb_zoom_out'),
          tooltip:'Alejar modelo 3D',icon:const Icon(Icons.zoom_out),
          onPressed:()=>setState((){
            _camera=_camera.zoomButton(false);_cacheKey=null;
          })),
        IconButton(key:const Key('skinned_glb_reset_camera'),
          tooltip:'Restablecer vista 3D',icon:const Icon(Icons.center_focus_strong),
          onPressed:()=>setState((){
            _camera=const GlbCameraPose();_cacheKey=null;
          })),
      ]),
    ]);
  }
}
