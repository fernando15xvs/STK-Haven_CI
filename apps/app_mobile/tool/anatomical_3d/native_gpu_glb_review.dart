// Experimental native OpenGL ES / Metal rasterization of a *static* GLB pose.
// The existing Dart CPU solver handles morphs and joint skinning. Native GPU
// performs interpolated color and per-pixel depth tests (not GPU skinning).
// No production exercise route, pubspec assets or new dependencies.
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anatomical_glb_runtime.dart';

const stkAnatomyGpuViewType='stk_haven/anatomy_gpu_static';
const _channelPrefix='stk_haven/anatomy_gpu_static/';
const maxGpuReviewTriangles=25000;
const gpuReviewStride=7; // clip x/y, depth 0..1, vertex RGBA 0..1

/// Expands indexed triangle draws for GLES/Metal depth-buffer rasterization.
/// Exactly the same CPU-skinned vertices and per-muscle theme colors as Canvas.
@immutable
class GpuReviewPacket {
  const GpuReviewPacket(this.vertices,this.triangleCount);
  final Float32List vertices;
  final int triangleCount;

  static GpuReviewPacket fromFrame(GlbDrawFrame frame,Size size) {
    if(!frame.finite||size.width<100||size.height<100||
       !size.width.isFinite||!size.height.isFinite||
       frame.triangles<1||frame.triangles>maxGpuReviewTriangles) {
      throw const FormatException('Invalid native GPU review geometry');
    }
    final floats=Float32List(frame.triangles*3*gpuReviewStride);
    var out=0;
    for(final part in frame.parts) {
      if(part.indices.length%3!=0||
         part.colors.length!=part.positions.length||
         part.depths.length!=part.positions.length) {
        throw const FormatException('Invalid native GPU part streams');
      }
      for(final index in part.indices) {
        if(index<0||index>=part.positions.length||
           out+gpuReviewStride>floats.length) {
          throw const FormatException('Out-of-range GPU triangle index');
        }
        final p=part.positions[index],z=part.depths[index];
        if(!p.dx.isFinite||!p.dy.isFinite||!z.isFinite||
           z<=0||z>100) {
          throw const FormatException('Nonfinite or unsafe GPU vertex');
        }
        final color=part.colors[index].toARGB32();
        floats[out++]=(p.dx/size.width*2-1).clamp(-4.0,4.0);
        floats[out++]=(1-p.dy/size.height*2).clamp(-4.0,4.0);
        // Farther camera-space Z is larger, so nearer geometry wins the
        // native depth test. GL/Metal clip-space Z convention is 0..1 here.
        floats[out++]=((z-.5)/30).clamp(0.0,1.0);
        floats[out++]=((color>>16)&255)/255.0;
        floats[out++]=((color>>8)&255)/255.0;
        floats[out++]=(color&255)/255.0;
        floats[out++]=((color>>24)&255)/255.0;
      }
    }
    if(out!=floats.length) {
      throw const FormatException('GPU triangle count inconsistent');
    }
    return GpuReviewPacket(floats,frame.triangles);
  }
}

@immutable
class NativeGpuReviewDraw {
  const NativeGpuReviewDraw({required this.packet,required this.background});
  final GpuReviewPacket packet;
  final Color background;
  Map<String,Object> encode() {
    final c=background.toARGB32();
    return {
      'vertices':packet.vertices,
      'background':Float32List.fromList([
        ((c>>16)&255)/255.0,((c>>8)&255)/255.0,
        (c&255)/255.0,((c>>24)&255)/255.0,
      ]),
    };
  }
}

/// Opt-in static experiment. Never used during 24fps exercise playback.
/// Uses Android GLSurfaceView and iOS MetalKit MTKView; failures fall back
/// to the tested Flutter Canvas rasterizer, not an empty exercise card.
class NativeGpuGlbReview extends StatefulWidget {
  const NativeGpuGlbReview({
    super.key,required this.scene,required this.size,
    required this.materials,required this.background,
    this.elapsed=2,this.dark=true,this.orbit=0,this.elevation=0,this.zoom=1,
    this.enabled=false,
  });
  final GlbSkinnedScene scene;
  final double size,elapsed,orbit,elevation,zoom;
  final bool dark,enabled;
  final Map<String,Color> materials;
  final Color background;

  @override
  State<NativeGpuGlbReview> createState()=>_NativeGpuGlbReviewState();
}

class _NativeGpuGlbReviewState extends State<NativeGpuGlbReview> {
  MethodChannel? _channel;
  bool _failed=false;
  int _serial=0;

  GlbDrawFrame _frame() => widget.scene.frame(widget.elapsed,
    Size.square(widget.size),widget.materials,
    dark:widget.dark,orbit:widget.orbit,elevation:widget.elevation,
    zoom:widget.zoom,depthSlices:1,poseNormals:true);

  Future<void> _send() async {
    final channel=_channel;
    if(channel==null||_failed||!mounted||!widget.enabled)return;
    final stamp=++_serial;
    try {
      final frame=_frame();
      final packet=GpuReviewPacket.fromFrame(frame,Size.square(widget.size));
      await channel.invokeMethod<void>('draw',
        NativeGpuReviewDraw(packet:packet,background:widget.background).encode());
    } catch (_) {
      if(mounted&&stamp==_serial)setState(()=>_failed=true);
    }
  }

  void _created(int id) {
    _channel=MethodChannel('$_channelPrefix$id');
    _send();
  }

  @override
  void didUpdateWidget(covariant NativeGpuGlbReview old) {
    super.didUpdateWidget(old);
    if(old.scene!=widget.scene||old.elapsed!=widget.elapsed||
       old.orbit!=widget.orbit||old.elevation!=widget.elevation||
       old.zoom!=widget.zoom||old.dark!=widget.dark||
       old.size!=widget.size||old.materials!=widget.materials||
       old.background!=widget.background||old.enabled!=widget.enabled) {
      _send();
    }
  }

  @override
  void dispose() {
    _serial++;
    _channel=null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNative=defaultTargetPlatform==TargetPlatform.android||
        defaultTargetPlatform==TargetPlatform.iOS;
    if(!widget.enabled||_failed||!isNative) {
      return SizedBox.square(dimension:widget.size,
        child:CustomPaint(painter:GlbSkinnedPainter(_frame(),widget.background)));
    }
    return SizedBox.square(dimension:widget.size,child:
      defaultTargetPlatform==TargetPlatform.android
      ? AndroidView(viewType:stkAnatomyGpuViewType,
          onPlatformViewCreated:_created)
      : UiKitView(viewType:stkAnatomyGpuViewType,
          onPlatformViewCreated:_created));
  }
}
