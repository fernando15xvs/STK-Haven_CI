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

/// Reuses an acknowledged mesh only if every vertex float is unchanged.
/// A view recreation MUST create a fresh cache: native buffers are per view.
/// The 8 glTF morphs are still CPU-side, so a changed pose uploads vertices.
class GpuSkinningMeshCache {
  Float32List? _acknowledgedVertices;

  bool get hasMesh => _acknowledgedVertices != null;

  Map<String,Object> encode(GpuSkinningPacket packet,Color background) {
    final payload=packet.encode(background);
    final old=_acknowledgedVertices;
    if(old!=null&&old.length==packet.vertices.length) {
      var identical=true;
      for(var i=0;i<old.length;i++) {
        if(old[i]!=packet.vertices[i]) {identical=false;break;}
      }
      if(identical) {
        payload.remove('vertices');
        payload['reuseMesh']=true;
      }
    }
    return payload;
  }

  void acknowledge(GpuSkinningPacket packet) {
    // Do not retain a caller-owned, mutable typed buffer.
    _acknowledgedVertices=Float32List.fromList(packet.vertices);
  }

  void reset() => _acknowledgedVertices=null;
}

const int stkGpuMorphCount=8;
const int stkGpuMorphDeltaStride=24;

/// v9.3 transport: full base geometry and eight morph targets only for the
/// first acknowledged packet (or when scene/palette changes). Later frames
/// contain just eight morph weights, the 55 bone matrices and camera.
@immutable
class GpuMorphPacket {
  const GpuMorphPacket(this.vertices,this.deltas,this.morphWeights,
      this.bones,this.camera,this.triangles,this.includesMesh);
  final Float32List vertices,deltas,morphWeights,bones,camera;
  final int triangles;
  final bool includesMesh;

  factory GpuMorphPacket.fromScene(GlbSkinnedScene scene,double elapsed,
      Size size,Map<String,Color> materials,{bool dark=true,double orbit=0,
      double elevation=0,double zoom=1,bool includeMesh=true}) {
    final source=scene.shaderMorphSource(elapsed,size,materials,
      dark:dark,orbit:orbit,elevation:elevation,zoom:zoom,
      includeMesh:includeMesh);
    final packet=GpuMorphPacket(source.vertices,source.deltas,
      source.morphWeights,source.bones,source.camera,source.triangles,
      includeMesh);
    packet.validate();
    return packet;
  }

  void validate() {
    if(triangles<1||triangles>stkGpuSkinMaxTriangles||
        morphWeights.length!=stkGpuMorphCount||
        morphWeights.any((v)=>!v.isFinite||v<0||v>1.025)||
        bones.length!=stkGpuSkinBoneCount*16||
        camera.length!=stkGpuSkinCameraFloats||
        bones.any((v)=>!v.isFinite||v.abs()>1e6)||
        camera.any((v)=>!v.isFinite)||
        camera[7]<=0||camera[7]>4||
        camera[11]<=0||camera[11]>4) {
      throw const FormatException('Invalid morph GPU pose');
    }
    if(includesMesh) {
      if(deltas.length!=triangles*3*stkGpuMorphDeltaStride||
          deltas.any((v)=>!v.isFinite)) {
        throw const FormatException('Invalid eight-target morph stream');
      }
      GpuSkinningPacket(vertices,bones,camera,triangles).validate();
    } else if(vertices.isNotEmpty||deltas.isNotEmpty) {
      throw const FormatException('Compact morph packet carries mesh');
    }
  }

  Map<String,Object> encode(Color background) {
    validate();
    final c=background.toARGB32();
    return {
      if(includesMesh) ...{'vertices':vertices,'morphDeltas':deltas}
      else 'reuseMorphMesh':true,
      'morphWeights':morphWeights,
      'bones':bones,
      'camera':camera,
      'background':Float32List.fromList([
        ((c>>16)&255)/255,((c>>8)&255)/255,
        (c&255)/255,((c>>24)&255)/255,
      ]),
    };
  }
}

class GpuMorphTransportCache {
  GlbSkinnedScene? _scene;
  String? _appearance;
  bool requiresMesh(GlbSkinnedScene scene,String appearance) =>
      !identical(scene,_scene)||appearance!=_appearance;
  void acknowledge(GlbSkinnedScene scene,String appearance) {
    _scene=scene;
    _appearance=appearance;
  }
  void reset() { _scene=null;_appearance=null; }
}

/// v9.4 index stream uses 32-bit unsigned indices, not 16-bit: the model
/// may have over 65,535 referenced vertices before deduplication.
const int stkGpuIndexedStride=42;
const int stkGpuIndexedBudgetBytes=12*1024*1024;

/// A distinct, disabled review protocol. Deduplicates exact bind-pose vertex
/// attributes + all eight morph deltas; never merges across different colors
/// or poses solely because positions coincide.
@immutable
class GpuIndexedMorphPacket {
  const GpuIndexedMorphPacket(this.interleaved,this.indices,
      this.morphWeights,this.bones,this.camera,this.triangles,
      this.includesMesh);
  final Float32List interleaved,morphWeights,bones,camera;
  final Uint32List indices;
  final int triangles;
  final bool includesMesh;

  int get vertexCount => interleaved.length~/stkGpuIndexedStride;
  int get retainedBytes => interleaved.lengthInBytes+indices.lengthInBytes;
  int get expandedBytes => triangles*3*stkGpuIndexedStride*4;
  double get transportRatio => expandedBytes==0?0:retainedBytes/expandedBytes;

  factory GpuIndexedMorphPacket.fromScene(GlbSkinnedScene scene,double elapsed,
      Size size,Map<String,Color> materials,{bool dark=true,double orbit=0,
      double elevation=0,double zoom=1,bool includeMesh=true}) {
    final source=GpuMorphPacket.fromScene(scene,elapsed,size,materials,
      dark:dark,orbit:orbit,elevation:elevation,zoom:zoom,
      includeMesh:includeMesh);
    if(!includeMesh) {
      return GpuIndexedMorphPacket(Float32List(0),Uint32List(0),
        source.morphWeights,source.bones,source.camera,source.triangles,false)
        ..validate();
    }
    final vertices=source.vertices,deltas=source.deltas;
    final original=ByteData.sublistView(vertices);
    final correctives=ByteData.sublistView(deltas);
    final values=<double>[];
    final indexList=<int>[];
    final hashBuckets=<int,List<int>>{};
    final count=source.triangles*3;
    for(var i=0;i<count;i++) {
      var hash=0x811c9dc5;
      for(var j=0;j<stkGpuIndexedStride;j++) {
        final bits=j<stkGpuSkinStride
          ?original.getUint32((i*stkGpuSkinStride+j)*4,Endian.host)
          :correctives.getUint32(
              (i*stkGpuMorphDeltaStride+j-stkGpuSkinStride)*4,Endian.host);
        hash=((hash^bits)*0x01000193)&0xffffffff;
      }
      final bucket=hashBuckets.putIfAbsent(hash,()=>[]);
      var found=-1;
      for(final candidate in bucket) {
        var equal=true;
        for(var j=0;j<stkGpuIndexedStride;j++) {
          final v=j<stkGpuSkinStride
            ?vertices[i*stkGpuSkinStride+j]
            :deltas[i*stkGpuMorphDeltaStride+j-stkGpuSkinStride];
          if(values[candidate*stkGpuIndexedStride+j]!=v) {
            equal=false;break;
          }
        }
        if(equal) {found=candidate;break;}
      }
      if(found<0) {
        found=values.length~/stkGpuIndexedStride;
        for(var j=0;j<stkGpuIndexedStride;j++) {
          values.add(j<stkGpuSkinStride
            ?vertices[i*stkGpuSkinStride+j]
            :deltas[i*stkGpuMorphDeltaStride+j-stkGpuSkinStride]);
        }
        bucket.add(found);
      }
      indexList.add(found);
    }
    final packet=GpuIndexedMorphPacket(Float32List.fromList(values),
      Uint32List.fromList(indexList),source.morphWeights,source.bones,
      source.camera,source.triangles,true);
    packet.validate();
    return packet;
  }

  void validate() {
    if(triangles<1||triangles>stkGpuSkinMaxTriangles||
        morphWeights.length!=stkGpuMorphCount||
        morphWeights.any((w)=>!w.isFinite||w<0||w>1.025)||
        bones.length!=stkGpuSkinBoneCount*16||
        bones.any((x)=>!x.isFinite||x.abs()>1e6)||
        camera.length!=stkGpuSkinCameraFloats||
        camera.any((x)=>!x.isFinite)||
        camera[7]<=0||camera[7]>4||
        camera[11]<=0||camera[11]>4) {
      throw const FormatException('Invalid indexed morph pose');
    }
    if(!includesMesh) {
      if(interleaved.isNotEmpty||indices.isNotEmpty) {
        throw const FormatException('Compact indexed pose includes mesh');
      }
      return;
    }
    if(interleaved.isEmpty||
        interleaved.length%stkGpuIndexedStride!=0||
        indices.length!=triangles*3||
        vertexCount>stkGpuSkinMaxTriangles*3||
        retainedBytes>stkGpuIndexedBudgetBytes||
        interleaved.any((v)=>!v.isFinite)||
        indices.any((i)=>i>=vertexCount)) {
      throw const FormatException('Indexed morph GPU budget/index violation');
    }
    for(var offset=0;offset<interleaved.length;
        offset+=stkGpuIndexedStride) {
      var blend=0.0;
      for(var k=0;k<4;k++) {
        final bone=interleaved[offset+6+k];
        final weight=interleaved[offset+10+k];
        if(bone<0||bone>=stkGpuSkinBoneCount||
            bone!=bone.roundToDouble()||weight<0||weight>1.025) {
          throw const FormatException('Invalid indexed skin influence');
        }
        blend+=weight;
      }
      if((blend-1).abs()>.025) {
        throw const FormatException('Unnormalized indexed blend');
      }
      for(var k=14;k<18;k++) {
        if(interleaved[offset+k]<0||interleaved[offset+k]>1) {
          throw const FormatException('Invalid indexed material color');
        }
      }
    }
  }

  Map<String,Object> encode(Color background) {
    validate();
    final c=background.toARGB32();
    return {
      if(includesMesh) ...{'indexedVertices':interleaved,'indices':indices}
      else 'reuseIndexedMesh':true,
      'morphWeights':morphWeights,
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
    this.experimentalMorphGpu=false,this.experimentalIndexedGpu=false,
  });

  final GlbSkinnedScene scene;
  final double size,elapsed,orbit,elevation,zoom;
  final Map<String,Color> materials;
  final Color background;
  final bool dark,enabled,experimentalMorphGpu,experimentalIndexedGpu;

  @override
  State<NativeGpuSkinnedGlbReview> createState() =>
      _NativeGpuSkinnedGlbReviewState();
}

class _NativeGpuSkinnedGlbReviewState
    extends State<NativeGpuSkinnedGlbReview> {
  MethodChannel? _channel;
  bool _failed=false;
  int _sequence=0;
  Future<void> _pending=Future<void>.value();
  final GpuSkinningMeshCache _meshCache=GpuSkinningMeshCache();
  final GpuMorphTransportCache _morphCache=GpuMorphTransportCache();
  final GpuMorphTransportCache _indexedCache=GpuMorphTransportCache();

  GlbDrawFrame _canvasFrame() => widget.scene.frame(
    widget.elapsed,Size.square(widget.size),widget.materials,
    dark:widget.dark,orbit:widget.orbit,elevation:widget.elevation,
    zoom:widget.zoom,depthSlices:6,poseNormals:true,
  );

  // A PlatformView has one retained mesh. Serializing uploads prevents a
  // compact pose update from overtaking the first full mesh packet.
  void _scheduleSend() {
    final serial=++_sequence;
    _pending=_pending.then((_)=>_send(serial));
  }

  Future<void> _send(int serial) async {
    final channel=_channel;
    if(serial!=_sequence||channel==null||!mounted||
        !widget.enabled||_failed)return;
    try {
      if(widget.experimentalMorphGpu||widget.experimentalIndexedGpu) {
        // Stable against material map reallocation on Flutter rebuilds.
        final swatches=widget.materials.entries.toList()
          ..sort((a,b)=>a.key.compareTo(b.key));
        final appearance=[
          widget.dark.toString(),
          for(final e in swatches) '${e.key}:${e.value.toARGB32()}',
        ].join('|');
        final indexed=widget.experimentalIndexedGpu;
        final cache=indexed?_indexedCache:_morphCache;
        final includeMesh=cache.requiresMesh(widget.scene,appearance);
        final payload=indexed
          ?GpuIndexedMorphPacket.fromScene(widget.scene,widget.elapsed,
              Size.square(widget.size),widget.materials,dark:widget.dark,
              orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom,
              includeMesh:includeMesh).encode(widget.background)
          :GpuMorphPacket.fromScene(widget.scene,widget.elapsed,
              Size.square(widget.size),widget.materials,dark:widget.dark,
              orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom,
              includeMesh:includeMesh).encode(widget.background);
        final acknowledged=await channel.invokeMethod<bool>(
          indexed?'drawIndexedMorph':'drawMorphed',payload)
          .timeout(const Duration(seconds:5));
        if(acknowledged!=true)throw StateError('Morph GPU frame rejected');
        if(identical(channel,_channel)) {
          cache.acknowledge(widget.scene,appearance);
        }
      } else {
        final packet=GpuSkinningPacket.fromScene(widget.scene,widget.elapsed,
          Size.square(widget.size),widget.materials,dark:widget.dark,
          orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom);
        final payload=_meshCache.encode(packet,widget.background);
        final acknowledged=await channel.invokeMethod<bool>('drawSkinned',payload)
            .timeout(const Duration(seconds:5));
        if(acknowledged!=true) {
          throw StateError('Native shader did not acknowledge the frame');
        }
        if(identical(channel,_channel))_meshCache.acknowledge(packet);
      }
    } catch (_) {
      if(mounted&&_sequence==serial)setState(()=>_failed=true);
    }
  }

  void _created(int id) {
    _meshCache.reset();
    _morphCache.reset();
    _indexedCache.reset();
    _channel=MethodChannel('$stkGpuSkinView/$id');
    _scheduleSend();
  }

  @override
  void didUpdateWidget(covariant NativeGpuSkinnedGlbReview old) {
    super.didUpdateWidget(old);
    if(widget.experimentalMorphGpu!=old.experimentalMorphGpu||
       widget.experimentalIndexedGpu!=old.experimentalIndexedGpu) {
      _meshCache.reset();
      _morphCache.reset();
      _indexedCache.reset();
    }
    if(widget.scene!=old.scene||widget.elapsed!=old.elapsed||
       widget.size!=old.size||widget.background!=old.background||
       widget.materials!=old.materials||widget.dark!=old.dark||
       widget.orbit!=old.orbit||widget.elevation!=old.elevation||
       widget.zoom!=old.zoom||widget.enabled!=old.enabled||
       widget.experimentalMorphGpu!=old.experimentalMorphGpu||
       widget.experimentalIndexedGpu!=old.experimentalIndexedGpu) {
      _scheduleSend();
    }
  }

  @override
  void dispose(){
    _sequence++;_channel=null;_meshCache.reset();_morphCache.reset();
    _indexedCache.reset();
    super.dispose();
  }

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
