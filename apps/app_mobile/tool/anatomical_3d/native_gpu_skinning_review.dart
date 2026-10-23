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
      this.includesMesh,{this.mixedRigid=false});
  final Float32List interleaved,morphWeights,bones,camera;
  final Uint32List indices;
  final int triangles;
  final bool includesMesh;
  /// Only explicit v9.12 QA permits rigid world-space sentinel vertices.
  final bool mixedRigid;

  int get vertexCount => interleaved.length~/stkGpuIndexedStride;
  int get retainedBytes => interleaved.lengthInBytes+indices.lengthInBytes;
  int get expandedBytes => triangles*3*stkGpuIndexedStride*4;
  double get transportRatio => expandedBytes==0?0:retainedBytes/expandedBytes;

  factory GpuIndexedMorphPacket.fromScene(GlbSkinnedScene scene,double elapsed,
      Size size,Map<String,Color> materials,{bool dark=true,double orbit=0,
      double elevation=0,double zoom=1,bool includeMesh=true}) {
    // Build the indexed data straight from decoded glTF primitives. The v9.4
    // path allocated two expanded arrays BEFORE deduplication (~42 floats per
    // triangle corner); v9.5 never materializes either expanded stream.
    final source=scene.shaderIndexedMorphSource(elapsed,size,materials,
      dark:dark,orbit:orbit,elevation:elevation,zoom:zoom,
      includeMesh:includeMesh);
    final packet=GpuIndexedMorphPacket(source.vertices,source.indices,
      source.morphWeights,source.bones,source.camera,source.triangles,
      includeMesh);
    packet.validate();
    return packet;
  }

  /// Full upload at every paused pose, never cached: equipment moves.
  factory GpuIndexedMorphPacket.fromMixedScene(
      GlbSkinnedScene scene,double elapsed,Size size,
      Map<String,Color> materials,{bool dark=true,double orbit=0,
      double elevation=0,double zoom=1}) {
    if(!scene.containsRigidEquipment) {
      throw const FormatException('Expected mixed review scene');
    }
    final source=scene.shaderIndexedMorphSource(elapsed,size,materials,
      dark:dark,orbit:orbit,elevation:elevation,zoom:zoom,
      includeRigid:true);
    final packet=GpuIndexedMorphPacket(source.vertices,source.indices,
      source.morphWeights,source.bones,source.camera,source.triangles,true,
      mixedRigid:true);
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
        final rigid=mixedRigid&&interleaved[offset+6]==-1;
        if((!rigid&&(bone<0||bone>=stkGpuSkinBoneCount))||
           (rigid&&bone!=(k==0?-1.0:0.0))||
           bone!=bone.roundToDouble()||weight<0||weight>1.025||
           (rigid&&weight!=(k==0?1.0:0.0))) {
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
      if(mixedRigid&&interleaved[offset+6]==-1) {
        for(var m=18;m<stkGpuIndexedStride;m++) {
          if(interleaved[offset+m]!=0) {
            throw const FormatException('Rigid equipment has nonzero morph');
          }
        }
      }
    }
    if(mixedRigid) {
      var rigidCount=0;
      for(var i=6;i<interleaved.length;i+=stkGpuIndexedStride) {
        if(interleaved[i]==-1)rigidCount++;
      }
      if(rigidCount<3)throw const FormatException('Missing QA equipment');
    }
  }

  Map<String,Object> encode(Color background) {
    validate();
    final c=background.toARGB32();
    return {
      if(includesMesh) ...{
        'indexedVertices':interleaved,
        // StandardMessageCodec supports Int32List, not Uint32List.
        'indices':Int32List.fromList(indices),
      } else 'reuseIndexedMesh':true,
      if(mixedRigid) 'mixedRigid':true,
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

/// Deterministic 12 fps maximum QA probe. This only throttles enqueueing:
/// MethodChannel ACK serialization still provides backpressure. No real-time
/// performance claim should be inferred from this clock.
class GpuProbeFrameGate {
  static const int maxFramesPerSecond=12;
  int? _lastFrame;

  bool allow(double elapsed,{bool force=false}) {
    if(!elapsed.isFinite||elapsed<0) {
      throw const FormatException('Invalid GPU QA probe time');
    }
    final frame=(elapsed*maxFramesPerSecond).floor();
    if(!force&&_lastFrame==frame)return false;
    _lastFrame=frame;
    return true;
  }

  void reset() => _lastFrame=null;
}

/// Diagnostic wall-clock data: native acknowledgement does not certify a
/// completed GPU draw or a measured display frame. Never use for FPS claims.
@immutable
class GpuQaMetricsSnapshot {
  const GpuQaMetricsSnapshot({
    required this.requested,required this.sent,required this.acknowledged,
    required this.superseded,required this.throttled,required this.failures,
    required this.inFlight,required this.maxInFlight,
    required this.lastAckMs,required this.maxAckMs,
    required this.lastPayloadBytes,required this.totalPayloadBytes,
  });
  final int requested,sent,acknowledged,superseded,throttled,failures;
  final int inFlight,maxInFlight,lastAckMs,maxAckMs;
  final int lastPayloadBytes,totalPayloadBytes;
}

/// Mutable counters deliberately local to one internal PlatformView.
class GpuQaMetrics {
  int requested=0,sent=0,acknowledged=0,superseded=0,throttled=0;
  int failures=0,inFlight=0,maxInFlight=0,lastAckMs=0,maxAckMs=0;
  int lastPayloadBytes=0,totalPayloadBytes=0;

  void request() => requested++;
  void supersede() => superseded++;
  void throttle() => throttled++;
  void begin(int payloadBytes) {
    if(payloadBytes<0||payloadBytes>stkGpuIndexedBudgetBytes*3) {
      throw const FormatException('Invalid QA transfer byte count');
    }
    sent++;
    inFlight++;
    if(inFlight>maxInFlight)maxInFlight=inFlight;
    lastPayloadBytes=payloadBytes;
    totalPayloadBytes+=payloadBytes;
  }
  void finish(int elapsedMs,{required bool success}) {
    if(elapsedMs<0)throw const FormatException('Invalid QA latency');
    if(inFlight>0)inFlight--;
    lastAckMs=elapsedMs;
    if(elapsedMs>maxAckMs)maxAckMs=elapsedMs;
    if(success) {acknowledged++;} else {failures++;}
  }
  GpuQaMetricsSnapshot get snapshot => GpuQaMetricsSnapshot(
    requested:requested,sent:sent,acknowledged:acknowledged,
    superseded:superseded,throttled:throttled,failures:failures,
    inFlight:inFlight,maxInFlight:maxInFlight,
    lastAckMs:lastAckMs,maxAckMs:maxAckMs,
    lastPayloadBytes:lastPayloadBytes,
    totalPayloadBytes:totalPayloadBytes,
  );
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
    this.playbackProbe=false,this.onMetrics,
    this.experimentalMixedGpu=false,
  });

  final GlbSkinnedScene scene;
  final double size,elapsed,orbit,elevation,zoom;
  final Map<String,Color> materials;
  final Color background;
  final bool dark,enabled,experimentalMorphGpu,experimentalIndexedGpu;
  /// Hidden static-only mixed GLES3/Metal QA; never use for playback.
  final bool experimentalMixedGpu;
  /// Internal 12-fps-only QA; never enabled from workout/catalog routes.
  final bool playbackProbe;
  /// Optional internal-only telemetry. Not connected to app analytics.
  final ValueChanged<GpuQaMetricsSnapshot>? onMetrics;

  @override
  State<NativeGpuSkinnedGlbReview> createState() =>
      _NativeGpuSkinnedGlbReviewState();
}

class _NativeGpuSkinnedGlbReviewState
    extends State<NativeGpuSkinnedGlbReview> {
  MethodChannel? _channel;
  bool _failed=false;
  int _sequence=0;
  int _viewEpoch=0;
  bool _pumpActive=false;
  bool _queued=false;
  final GpuQaMetrics _metrics=GpuQaMetrics();
  final GpuSkinningMeshCache _meshCache=GpuSkinningMeshCache();
  final GpuMorphTransportCache _morphCache=GpuMorphTransportCache();
  final GpuMorphTransportCache _indexedCache=GpuMorphTransportCache();
  final GpuProbeFrameGate _probeGate=GpuProbeFrameGate();

  GlbDrawFrame _canvasFrame() => widget.scene.frame(
    widget.elapsed,Size.square(widget.size),widget.materials,
    dark:widget.dark,orbit:widget.orbit,elevation:widget.elevation,
    zoom:widget.zoom,depthSlices:6,poseNormals:true,
  );

  // Coalescing scheduler: only one MethodChannel call can be in flight and
  // at most ONE pending pose is remembered. A slow native renderer does not
  // accumulate an unbounded chain of Future callbacks.
  void _scheduleSend({bool force=false}) {
    if(widget.playbackProbe&&widget.experimentalIndexedGpu&&
        !_probeGate.allow(widget.elapsed,force:force)) {
      _metrics.throttle();
      return;
    }
    ++_sequence;
    _metrics.request();
    if(_pumpActive) {
      if(_queued)_metrics.supersede();
      _queued=true;
      return;
    }
    _pumpActive=true;
    _drain();
  }

  Future<void> _drain() async {
    try {
      do {
        _queued=false;
        final serial=_sequence;
        await _send(serial);
      } while(_queued&&mounted&&!_failed);
    } finally {
      _pumpActive=false;
    }
  }

  void _publish() {
    if(mounted)widget.onMetrics?.call(_metrics.snapshot);
  }

  Future<void> _send(int serial) async {
    final channel=_channel;
    final epoch=_viewEpoch;
    if(serial!=_sequence||channel==null||!mounted||
        !widget.enabled||_failed)return;
    final started=Stopwatch()..start();
    var succeeded=false;
    try {
      if(widget.experimentalMorphGpu||widget.experimentalIndexedGpu) {
        // Appearance must be calculated from actual semantic region colors.
        final scene=widget.scene;
        final swatches=widget.materials.entries.toList()
          ..sort((a,b)=>a.key.compareTo(b.key));
        final appearance=[
          widget.dark.toString(),
          for(final e in swatches) '${e.key}:${e.value.toARGB32()}',
        ].join('|');
        final indexed=widget.experimentalIndexedGpu;
        final cache=indexed?_indexedCache:_morphCache;
        final mixed=indexed&&widget.experimentalMixedGpu&&
            scene.containsRigidEquipment&&!widget.playbackProbe;
        final includeMesh=mixed||cache.requiresMesh(scene,appearance);
        final payload=mixed
          ?GpuIndexedMorphPacket.fromMixedScene(scene,widget.elapsed,
              Size.square(widget.size),widget.materials,dark:widget.dark,
              orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom)
              .encode(widget.background)
          :indexed
          ?GpuIndexedMorphPacket.fromScene(scene,widget.elapsed,
              Size.square(widget.size),widget.materials,dark:widget.dark,
              orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom,
              includeMesh:includeMesh).encode(widget.background)
          :GpuMorphPacket.fromScene(scene,widget.elapsed,
              Size.square(widget.size),widget.materials,dark:widget.dark,
              orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom,
              includeMesh:includeMesh).encode(widget.background);
        _metrics.begin(_typedPayloadBytes(payload));
        final acknowledged=await channel.invokeMethod<bool>(
          indexed?'drawIndexedMorph':'drawMorphed',payload)
          .timeout(const Duration(seconds:5));
        if(acknowledged!=true)throw StateError('Morph GPU frame rejected');
        if(identical(channel,_channel)&&epoch==_viewEpoch) {
          cache.acknowledge(scene,appearance);
        }
      } else {
        final packet=GpuSkinningPacket.fromScene(widget.scene,widget.elapsed,
          Size.square(widget.size),widget.materials,dark:widget.dark,
          orbit:widget.orbit,elevation:widget.elevation,zoom:widget.zoom);
        final payload=_meshCache.encode(packet,widget.background);
        _metrics.begin(_typedPayloadBytes(payload));
        final acknowledged=await channel.invokeMethod<bool>('drawSkinned',payload)
            .timeout(const Duration(seconds:5));
        if(acknowledged!=true) {
          throw StateError('Native shader did not acknowledge the frame');
        }
        if(identical(channel,_channel)&&epoch==_viewEpoch) {
          _meshCache.acknowledge(packet);
        }
      }
      succeeded=true;
    } catch (_) {
      if(mounted&&identical(channel,_channel)&&epoch==_viewEpoch&&
          _sequence==serial) {
        setState(()=>_failed=true);
      }
    } finally {
      started.stop();
      // Even a malformed CPU packet counts as a failed attempted request.
      _metrics.finish(started.elapsedMilliseconds,success:succeeded);
      _publish();
    }
  }

  static int _typedPayloadBytes(Map<String,Object> packet) {
    var bytes=0;
    for(final value in packet.values) {
      if(value is TypedData)bytes+=value.lengthInBytes;
    }
    return bytes;
  }

  void _created(int id) {
    _meshCache.reset();
    _morphCache.reset();
    _indexedCache.reset();
    _probeGate.reset();
    _viewEpoch++;
    _channel=MethodChannel('$stkGpuSkinView/$id');
    _scheduleSend(force:true);
  }

  @override
  void didUpdateWidget(covariant NativeGpuSkinnedGlbReview old) {
    super.didUpdateWidget(old);
    if(widget.experimentalMorphGpu!=old.experimentalMorphGpu||
       widget.experimentalIndexedGpu!=old.experimentalIndexedGpu||
       widget.playbackProbe!=old.playbackProbe||
        widget.experimentalMixedGpu!=old.experimentalMixedGpu) {
      _meshCache.reset();
      _morphCache.reset();
      _indexedCache.reset();
      _probeGate.reset();
      _viewEpoch++;
    }
    if(widget.scene!=old.scene||widget.elapsed!=old.elapsed||
       widget.size!=old.size||widget.background!=old.background||
       widget.materials!=old.materials||widget.dark!=old.dark||
       widget.orbit!=old.orbit||widget.elevation!=old.elevation||
       widget.zoom!=old.zoom||widget.enabled!=old.enabled||
       widget.experimentalMorphGpu!=old.experimentalMorphGpu||
       widget.experimentalIndexedGpu!=old.experimentalIndexedGpu||
       widget.playbackProbe!=old.playbackProbe||
        widget.experimentalMixedGpu!=old.experimentalMixedGpu) {
      final force=widget.scene!=old.scene||widget.size!=old.size||
          widget.background!=old.background||
          widget.materials!=old.materials||widget.dark!=old.dark||
          widget.orbit!=old.orbit||widget.elevation!=old.elevation||
          widget.zoom!=old.zoom||widget.enabled!=old.enabled||
          widget.experimentalMorphGpu!=old.experimentalMorphGpu||
          widget.experimentalIndexedGpu!=old.experimentalIndexedGpu||
          widget.playbackProbe!=old.playbackProbe||
        widget.experimentalMixedGpu!=old.experimentalMixedGpu;
      _scheduleSend(force:force);
    }
  }

  @override
  void dispose(){
    _sequence++;_viewEpoch++;_queued=false;
    _channel=null;_meshCache.reset();_morphCache.reset();
    _indexedCache.reset();
    _probeGate.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final native=defaultTargetPlatform==TargetPlatform.android||
        defaultTargetPlatform==TargetPlatform.iOS;
    // Fail closed if a caller bypasses AnatomicalGlbPreview's QA gate:
    // no body-only GPU when the scene contains bar/bench, no mixed playback.
    final mixedSafe=!widget.scene.containsRigidEquipment||
        (widget.experimentalMixedGpu&&widget.experimentalIndexedGpu&&
         !widget.playbackProbe);
    if(!widget.enabled||_failed||!native||!mixedSafe) {
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
