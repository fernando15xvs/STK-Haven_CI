// Native GPU 55-joint skinning experiment. CPU evaluates the eight morph
// curves; GLES3/Metal shaders transform every vertex by the 55 bones.
// Separate from the existing stable GLES2 static rasterizer and 229 catalog.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anatomical_glb_runtime.dart';

const stkGpuSkinView='stk_haven/anatomy_gpu_skinning';
const int stkGpuSkinStride=18;
const int stkGpuSkinBoneCount=55;
const int stkGpuSkinCameraFloats=20;
const int stkGpuSkinMaxTriangles=25000;

@immutable
class GpuSkinningPacket {
  const GpuSkinningPacket(this.vertices,this.bones,this.camera,this.triangles);
  final Float32List vertices,bones,camera;
  final int triangles;

  factory GpuSkinningPacket.fromScene(GlbSkinnedScene scene,double elapsed,
      Size size,Map<String,Color> materials,{bool dark=true,double orbit=0,
      double elevation=0,double zoom=1}) {
    final source=scene.shaderSkinSource(elapsed,size,materials,
      dark:dark,orbit:orbit,elevation:elevation,zoom:zoom);
    final packet=GpuSkinningPacket(source.vertices,source.bones,
        source.camera,source.triangles);
    packet.validate();
    return packet;
  }

  void validate() {
    if(triangles<1||triangles>stkGpuSkinMaxTriangles||
       vertices.length!=triangles*3*stkGpuSkinStride||
       bones.length!=stkGpuSkinBoneCount*16||
       camera.length!=stkGpuSkinCameraFloats||
       vertices.any((v)=>!v.isFinite)||
       bones.any((v)=>!v.isFinite)||
       camera.any((v)=>!v.isFinite)) {
      throw const FormatException('Unsupported 55-joint GPU skin payload');
    }
    // 18-float stride: P(3), N(3), joint IDs(4), weights(4), RGBA(4).
    for(var i=0;i<vertices.length;i+=stkGpuSkinStride) {
      var sum=0.0;
      for(var j=0;j<4;j++) {
        final bone=vertices[i+6+j];
        final weight=vertices[i+10+j];
        if(bone<0||bone>=stkGpuSkinBoneCount||bone!=bone.roundToDouble()||
           weight<0||weight>1.025) {
          throw const FormatException('Invalid GPU vertex blend weights');
        }
        sum+=weight;
      }
      if((sum-1).abs()>.025) {
        throw const FormatException('Unnormalized GPU vertex weights');
      }
      for(var j=14;j<18;j++) {
        if(vertices[i+j]<0||vertices[i+j]>1) {
          throw const FormatException('Invalid GPU vertex color');
        }
      }
    }
    final sx=camera[7],sy=camera[11];
    if(sx<=0||sy<=0||sx>4||sy>4) {
      throw const FormatException('Invalid GPU projector');
    }
  }

  Map<String,Object> encode(Color background) {
    validate();
    final c=background.toARGB32();
    return {
      'vertices':vertices,
      'bones':bones,
      'camera':camera,
      'background':Float32List.fromList([
        ((c>>16)&255)/255,((c>>8)&255)/255,
        (c&255)/255,((c>>24)&255)/255,
      ]),
    };
  }
}

/// QA-only static shader-skinning PlatformView.
/// No ongoing animations are allowed: a new packet is sent only for an
/// explicit paused frame, so Android/iOS performance is not misrepresented.
class NativeGpuSkinnedGlbReview extends StatefulWidget {
  const NativeGpuSkinnedGlbReview({
    super.key,required this.scene,required this.size,required this.materials,
    required this.background,this.elapsed=2,this.dark=true,this.orbit=0,
    this.elevation=0,this.zoom=1,this.enabled=false,
  });

  final GlbSkinnedScene scene;
  final double size,elapsed,orbit,elevation,zoom;
  final Map<String,Color> materials;
  final Color background;
  final bool dark,enabled;

  @override
  State<NativeGpuSkinnedGlbReview> createState() =>
      _NativeGpuSkinnedGlbReviewState();
}

class _NativeGpuSkinnedGlbReviewState
    extends State<NativeGpuSkinnedGlbReview> {
  MethodChannel? _channel;
  bool _failed=false;
  int _sequence=0;

  GlbDrawFrame _canvasFrame() => widget.scene.frame(
    widget.elapsed,Size.square(widget.size),widget.materials,
    dark:widget.dark,orbit:widget.orbit,elevation:widget.elevation,
    zoom:widget.zoom,depthSlices:6,poseNormals:true,
  );

  Future<void> _send() async {
    final channel=_channel;
    if(channel==null||!mounted||!widget.enabled||_failed)return;
    final serial=++_sequence;
    try {
      final packet=GpuSkinningPacket.fromScene(widget.scene,widget.elapsed,
        Size.square(widget.size),widget.materials,dark:widget.dark,
        orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom);
      // An EGL/Metal surface may fail to initialize without delivering a
      // shader response. Never leave a blank PlatformView on screen forever.
      final acknowledged=await channel.invokeMethod<bool>('drawSkinned',
          packet.encode(widget.background))
          .timeout(const Duration(seconds:5));
      if(acknowledged!=true) {
        throw StateError('Native shader did not acknowledge the frame');
      }
    } catch (_) {
      if(mounted&&_sequence==serial)setState(()=>_failed=true);
    }
  }

  void _created(int id) {
    _channel=MethodChannel('$stkGpuSkinView/$id');
    _send();
  }

  @override
  void didUpdateWidget(covariant NativeGpuSkinnedGlbReview old) {
    super.didUpdateWidget(old);
    if(widget.scene!=old.scene||widget.elapsed!=old.elapsed||
       widget.size!=old.size||widget.background!=old.background||
       widget.materials!=old.materials||widget.dark!=old.dark||
       widget.orbit!=old.orbit||widget.elevation!=old.elevation||
       widget.zoom!=old.zoom||widget.enabled!=old.enabled) {
      _send();
    }
  }

  @override
  void dispose(){_sequence++;_channel=null;super.dispose();}

  @override
  Widget build(BuildContext context) {
    final native=defaultTargetPlatform==TargetPlatform.android||
        defaultTargetPlatform==TargetPlatform.iOS;
    if(!widget.enabled||_failed||!native) {
      return SizedBox.square(dimension:widget.size,
        child:CustomPaint(painter:GlbSkinnedPainter(
          _canvasFrame(),widget.background)));
    }
    return SizedBox.square(dimension:widget.size,child:
      defaultTargetPlatform==TargetPlatform.android
        ? AndroidView(viewType:stkGpuSkinView,
            onPlatformViewCreated:_created)
        : UiKitView(viewType:stkGpuSkinView,
            onPlatformViewCreated:_created));
  }
}
