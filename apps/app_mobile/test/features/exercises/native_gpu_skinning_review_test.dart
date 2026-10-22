import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/native_gpu_skinning_review.dart';

const names=<String>[
  'overhead_reach_bilateral','unilateral_reach_left',
  'unilateral_reach_right','bilateral_elbow_curl','hip_hinge',
  'squat_articulation','split_lunge_left',
];

Offset projected(GpuSkinningPacket packet,int start,Size size) {
  final v=packet.vertices,b=packet.bones,c=packet.camera;
  final x=v[start],y=v[start+1],z=v[start+2];
  var wx=0.0,wy=0.0,wz=0.0;
  for(var k=0;k<4;k++) {
    final joint=v[start+6+k].toInt();
    final weight=v[start+10+k];
    final base=joint*16;
    wx+=(b[base]*x+b[base+4]*y+b[base+8]*z+b[base+12])*weight;
    wy+=(b[base+1]*x+b[base+5]*y+b[base+9]*z+
        b[base+13])*weight;
    wz+=(b[base+2]*x+b[base+6]*y+b[base+10]*z+
        b[base+14])*weight;
  }
  final dx=wx-c[0],dy=wy-c[1],dz=wz-c[2];
  final depth=math.max(.6,dx*c[12]+dy*c[13]+dz*c[14]);
  final horizontal=(dx*c[4]+dy*c[5]+dz*c[6])*c[7]/depth;
  final vertical=(dx*c[8]+dy*c[9]+dz*c[10])*c[11]/depth+c[15];
  return Offset((horizontal+1)*size.width/2,
      (1-vertical)*size.height/2);
}

void main() {
  test('55-matrix typed packet rejects NaN, malformed blends and counts',() {
    final invalid=GpuSkinningPacket(
      Float32List.fromList(List<double>.filled(18*3,0)),
      Float32List(55*16),Float32List(20),1,
    );
    expect(()=>invalid.validate(),throwsFormatException);
    expect(stkGpuSkinStride,18);
    expect(stkGpuSkinBoneCount,55);
    expect(stkGpuSkinCameraFloats,20);
    expect(stkGpuSkinView,'stk_haven/anatomy_gpu_skinning');
  });

  test('GPU QA cache omits only byte-equivalent ACKed vertex mesh',() {
    GpuSkinningPacket packet([double position=0]) {
      final vertices=Float32List(3*stkGpuSkinStride);
      for(var i=0;i<vertices.length;i+=stkGpuSkinStride) {
        vertices[i]=position;
        vertices[i+10]=1; // Bone zero has full weight.
        vertices[i+14]=.8;
        vertices[i+15]=.8;
        vertices[i+16]=.8;
        vertices[i+17]=1;
      }
      final bones=Float32List(stkGpuSkinBoneCount*16);
      final camera=Float32List(stkGpuSkinCameraFloats);
      camera[7]=1;
      camera[11]=1;
      return GpuSkinningPacket(vertices,bones,camera,1);
    }
    const bg=Color(0xFF12181F);
    final cache=GpuSkinningMeshCache();
    final first=packet();
    final full=cache.encode(first,bg);
    expect(full.containsKey('vertices'),true);
    expect(full.containsKey('reuseMesh'),false);
    // No compact frames may be sent until the native upload acknowledges.
    expect(cache.encode(packet(),bg).containsKey('vertices'),true);
    cache.acknowledge(first);
    final compact=cache.encode(packet(),bg);
    expect(compact.containsKey('vertices'),false);
    expect(compact['reuseMesh'],true);
    expect(compact.keys.toSet(),
        {'bones','camera','background','reuseMesh'});
    expect(cache.encode(packet(.1),bg).containsKey('vertices'),true);
    // An old mutable packet must not corrupt the last-ACKed mesh.
    first.vertices[0]=.9;
    expect(cache.encode(packet(),bg).containsKey('vertices'),false);
    cache.reset();
    expect(cache.hasMesh,false);
    expect(cache.encode(packet(),bg).containsKey('vertices'),true);
  });

  test('v9.3 morph stream matches CPU pre-skinned vertices for seven clips',() {
    final data=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    const size=Size(320,320);
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(data,pattern:name);
      for(final elapsed in [0.0,1.0,2.0,3.0]) {
        final morphed=scene.shaderMorphSource(elapsed,size,const {});
        final cpu=scene.shaderSkinSource(elapsed,size,const {});
        expect(morphed.triangles,cpu.triangles);
        expect(morphed.vertices.length,cpu.vertices.length);
        expect(morphed.deltas.length,morphed.triangles*3*24);
        expect(morphed.morphWeights.length,8);
        expect(morphed.bones,orderedEquals(cpu.bones));
        expect(morphed.camera,orderedEquals(cpu.camera));
        final count=morphed.triangles*3;
        for(var vertex=0;vertex<count;vertex+=math.max(1,count~/70)) {
          for(var axis=0;axis<3;axis++) {
            var position=morphed.vertices[vertex*18+axis];
            for(var m=0;m<8;m++) {
              position+=morphed.deltas[vertex*24+m*3+axis]*
                  morphed.morphWeights[m];
            }
            expect((position-cpu.vertices[vertex*18+axis]).abs(),
                lessThan(0.0004),
                reason:'$name at $elapsed / vertex $vertex axis $axis');
          }
        }
        final pose=GpuMorphPacket.fromScene(scene,elapsed,size,const {},
            includeMesh:false);
        expect(pose.vertices,isEmpty);
        expect(pose.deltas,isEmpty);
        expect(pose.encode(const Color(0xFF12181F)).keys.toSet(),
            {'reuseMorphMesh','morphWeights','bones','camera','background'});
        final payload=GpuMorphPacket.fromScene(scene,elapsed,size,const {});
        expect(payload.encode(const Color(0xFF12181F)).keys.toSet(),
            {'vertices','morphDeltas','morphWeights','bones','camera',
             'background'});
        expect(payload.deltas.length,count*24);
      }
    }
  },timeout:const Timeout(Duration(minutes:6)));

  test('v9.3 ACK cache invalidates by scene, palette and view lifetime',() {
    final cache=GpuMorphTransportCache();
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final scene=GlbSkinnedScene.decodeMaster(bytes,
      pattern:'overhead_reach_bilateral');
    expect(cache.requiresMesh(scene,'light:blue'),true);
    cache.acknowledge(scene,'light:blue');
    expect(cache.requiresMesh(scene,'light:blue'),false);
    expect(cache.requiresMesh(scene,'dark:blue'),true);
    final sceneAgain=GlbSkinnedScene.decodeMaster(bytes,
      pattern:'overhead_reach_bilateral');
    expect(cache.requiresMesh(sceneAgain,'light:blue'),true);
    cache.reset();
    expect(cache.requiresMesh(scene,'light:blue'),true);
  });

  test('v9.6 diagnostic counters distinguish throttling, ACK and error',() {
    final telemetry=GpuQaMetrics();
    telemetry.request();
    telemetry.request();
    telemetry.throttle();
    telemetry.supersede();
    telemetry.begin(2048);
    expect(telemetry.snapshot.inFlight,1);
    expect(telemetry.snapshot.maxInFlight,1);
    telemetry.finish(19,success:true);
    final first=telemetry.snapshot;
    expect(first.requested,2);
    expect(first.sent,1);
    expect(first.acknowledged,1);
    expect(first.superseded,1);
    expect(first.throttled,1);
    expect(first.failures,0);
    expect(first.lastPayloadBytes,2048);
    expect(first.totalPayloadBytes,2048);
    expect(first.lastAckMs,19);
    expect(first.inFlight,0);
    telemetry.begin(128);
    telemetry.finish(41,success:false);
    final failed=telemetry.snapshot;
    expect(failed.sent,2);
    expect(failed.failures,1);
    expect(failed.maxInFlight,1);
    expect(failed.acknowledged,1);
    expect(failed.maxAckMs,41);
    expect(failed.lastAckMs,41);
    expect(failed.totalPayloadBytes,2176);
    expect(()=>telemetry.begin(-1),throwsFormatException);
    expect(()=>telemetry.finish(-5,success:true),throwsFormatException);
  });

  test('v9.6 direct mesh uses bounded typed storage and exact uint32 indices',
      () {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    const size=Size(320,320);
    final audit=<Map<String,Object>>[];
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(bytes,pattern:name);
      final mesh=scene.shaderIndexedMorphSource(0,size,const {});
      final packet=GpuIndexedMorphPacket.fromScene(scene,0,size,const {});
      expect(mesh.vertices,orderedEquals(packet.interleaved));
      expect(mesh.indices,orderedEquals(packet.indices));
      expect(mesh.indices.buffer.lengthInBytes,mesh.indices.lengthInBytes);
      final used=mesh.vertices.lengthInBytes;
      final capacity=mesh.vertices.buffer.lengthInBytes;
      expect(used,greaterThan(0));
      expect(capacity,greaterThanOrEqualTo(used));
      // Last geometric allocation is retained via sublist view, rather
      // than allocating a second contiguous Float32List.fromList copy.
      expect(capacity,lessThanOrEqualTo(
        2*used+2048*stkGpuIndexedStride*4));
      expect(mesh.indices.length,mesh.triangles*3);
      expect(packet.retainedBytes,lessThanOrEqualTo(stkGpuIndexedBudgetBytes));
      audit.add({
        'clip':name,
        'usedVertexBytes':used,
        'allocatedVertexBackingBytes':capacity,
        'indexBytes':mesh.indices.lengthInBytes,
        'withinWireBudget':true,
      });
    }
    final destination=File(
      'build/cc0_master_v7_flutter_qa/indexed_morph_memory_v96.json');
    destination.parent.createSync(recursive:true);
    destination.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema':'stk_gpu_indexed_v96_qa_only',
        'description':'Dart typed data wire and backing bytes, not physical RAM',
        'physicalGpuMemoryMeasured':false,
        'nativeFramePresentMeasured':false,
        'approvedAssets':0,'enabledAssets':0,
        'clips':audit,
      }),
    );
  },timeout:const Timeout(Duration(minutes:5)));

  test('v9.5 direct glTF indexing matches expanded morph wire geometry',
      () {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    const size=Size(320,320);
    final report=<Map<String,Object>>[];
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(bytes,pattern:name);
      final expanded=GpuMorphPacket.fromScene(scene,1.75,size,const {});
      final direct=scene.shaderIndexedMorphSource(1.75,size,const {});
      final packet=GpuIndexedMorphPacket.fromScene(scene,1.75,size,const {});
      expect(direct.triangles,expanded.triangles);
      expect(direct.vertices,orderedEquals(packet.interleaved));
      expect(direct.indices,orderedEquals(packet.indices));
      expect(direct.morphWeights,orderedEquals(expanded.morphWeights));
      expect(direct.bones,orderedEquals(expanded.bones));
      expect(direct.camera,orderedEquals(expanded.camera));
      final count=direct.indices.length;
      for(var k=0;k<count;k+=math.max(1,count~/300)) {
        final first=direct.indices[k]*stkGpuIndexedStride;
        final base=k*stkGpuSkinStride;
        final morph=k*stkGpuMorphDeltaStride;
        for(var i=0;i<stkGpuSkinStride;i++) {
          expect(direct.vertices[first+i],expanded.vertices[base+i],
            reason:'$name vertex=$k base-channel=$i');
        }
        for(var i=0;i<stkGpuMorphDeltaStride;i++) {
          expect(direct.vertices[first+stkGpuSkinStride+i],
            expanded.deltas[morph+i],
            reason:'$name vertex=$k morph-channel=$i');
        }
      }
      for(final t in [0.0,1.0,2.0,3.0]) {
        final noMesh=scene.shaderIndexedMorphSource(t,size,const {},
          includeMesh:false);
        expect(noMesh.vertices,isEmpty);
        expect(noMesh.indices,isEmpty);
        expect(noMesh.bones.length,55*16);
        expect(noMesh.morphWeights.length,8);
        final match=scene.shaderMorphSource(t,size,const {},
          includeMesh:false);
        expect(noMesh.bones,orderedEquals(match.bones));
        expect(noMesh.morphWeights,orderedEquals(match.morphWeights));
      }
      report.add({
        'clip':name,
        'triangles':packet.triangles,
        'uniqueVertices':packet.vertexCount,
        'initialIndexedBytes':packet.retainedBytes,
        'previousExpandedWireBytes':packet.expandedBytes,
        'transientExpandedArraysEliminated':true,
        'physicalRamMeasured':false,
      });
    }
    final output=File(
      'build/cc0_master_v7_flutter_qa/indexed_morph_memory_v95.json');
    output.parent.createSync(recursive:true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema':'stk_gpu_indexed_v95_qa_only',
        'scope':'static_buffer_bytes_not_physical_peak_memory',
        'approvedAssets':0,
        'enabledAssets':0,
        'maxProbeHz':GpuProbeFrameGate.maxFramesPerSecond,
        'clips':report,
      }));
  },timeout:const Timeout(Duration(minutes:8)));

  test('v9.5 probe throttles to 12Hz, resumes, and allows camera changes',() {
    final gate=GpuProbeFrameGate();
    expect(GpuProbeFrameGate.maxFramesPerSecond,12);
    var accepted=0;
    for(var frame=0;frame<240;frame++) {
      if(gate.allow(frame/120))accepted++;
    }
    expect(accepted,24); // 120Hz input over 2 seconds.
    expect(gate.allow(239/120),false);
    expect(gate.allow(239/120,force:true),true);
    expect(gate.allow(239/120),false);
    gate.reset();
    expect(gate.allow(0),true);
    expect(()=>gate.allow(double.nan),throwsFormatException);
    expect(()=>gate.allow(-1),throwsFormatException);
  });

  test('v9.4 indexed QA keeps vertex/morph parity and bounded byte usage',
      () {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    const size=Size(320,320);
    final summary=<Map<String,Object>>[];
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(bytes,pattern:name);
      final expanded=GpuMorphPacket.fromScene(scene,2,size,const {});
      final indexed=GpuIndexedMorphPacket.fromScene(scene,2,size,const {});
      expect(indexed.triangles,expanded.triangles);
      expect(indexed.indices.length,indexed.triangles*3);
      expect(indexed.retainedBytes,lessThanOrEqualTo(stkGpuIndexedBudgetBytes));
      expect(indexed.retainedBytes,lessThan(indexed.expandedBytes));
      expect(indexed.vertexCount,lessThan(indexed.indices.length));
      final positions=expanded.vertices,deltas=expanded.deltas;
      final samples=indexed.indices.length;
      for(var t=0;t<samples;t+=math.max(1,samples~/160)) {
        final vertex=indexed.indices[t];
        final start=vertex*stkGpuIndexedStride;
        for(var axis=0;axis<stkGpuIndexedStride;axis++) {
          final expected=axis<stkGpuSkinStride
            ?positions[t*stkGpuSkinStride+axis]
            :deltas[t*stkGpuMorphDeltaStride+axis-stkGpuSkinStride];
          expect(indexed.interleaved[start+axis],expected,
            reason:'$name index $t attribute $axis');
        }
      }
      expect(indexed.encode(const Color(0xFF12181F)).keys.toSet(),
        {'indexedVertices','indices','morphWeights','bones','camera',
          'background'});
      final compact=GpuIndexedMorphPacket.fromScene(scene,3,size,const {},
        includeMesh:false);
      expect(compact.interleaved,isEmpty);
      expect(compact.indices,isEmpty);
      expect(compact.encode(const Color(0xFF12181F)).keys.toSet(),
        {'reuseIndexedMesh','morphWeights','bones','camera','background'});
      expect(compact.bones.length,55*16);
      summary.add({
        'pattern':name,
        'triangles':indexed.triangles,
        'uniqueVertices':indexed.vertexCount,
        'expandedVertices':indexed.indices.length,
        'expandedMeshBytes':indexed.expandedBytes,
        'indexedMeshBytes':indexed.retainedBytes,
        'ratio':indexed.transportRatio,
        'withinStaticBudget':true,
      });
    }
    final destination=File(
      'build/cc0_master_v7_flutter_qa/indexed_morph_memory_v94.json',
    );
    destination.parent.createSync(recursive:true);
    destination.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'type':'static_wire_byte_budget_not_measured_device_RAM',
        'platform':'internal_QA_only',
        'model':'CC0_55_joint_v7',
        'deviceMemoryMeasured':false,
        'physicalFPSMeasured':false,
        'patterns':summary,
        'approvedAssets':0,
        'enabledAssets':0,
      }),
    );
  },timeout:const Timeout(Duration(minutes:8)));

  test('v9.4 indexed payload rejects invalid references and resets on switch',
      () {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final scene=GlbSkinnedScene.decodeMaster(bytes,
      pattern:'overhead_reach_bilateral');
    final indexed=GpuIndexedMorphPacket.fromScene(
      scene,1,const Size(320,320),const {});
    final invalid=Uint32List.fromList(indexed.indices);
    invalid[0]=indexed.vertexCount;
    final malformed=GpuIndexedMorphPacket(
      indexed.interleaved,invalid,indexed.morphWeights,indexed.bones,
      indexed.camera,indexed.triangles,true);
    expect(()=>malformed.validate(),throwsFormatException);
    final wrongCompact=GpuIndexedMorphPacket(
      indexed.interleaved,Uint32List(0),indexed.morphWeights,indexed.bones,
      indexed.camera,indexed.triangles,false);
    expect(()=>wrongCompact.validate(),throwsFormatException);
    final cache=GpuMorphTransportCache();
    expect(cache.requiresMesh(scene,'dark:red'),true);
    cache.acknowledge(scene,'dark:red');
    expect(cache.requiresMesh(scene,'dark:red'),false);
    cache.reset();
    expect(cache.requiresMesh(scene,'dark:red'),true);
  },timeout:const Timeout(Duration(minutes:4)));

  test('v9.4 compact pose sampling prepares a disabled 24-step probe',() {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final scene=GlbSkinnedScene.decodeMaster(bytes,
      pattern:'squat_articulation');
    const size=Size(320,320);
    final watch=Stopwatch()..start();
    var sampled=0;
    for(var step=0;step<24;step++) {
      final packet=GpuIndexedMorphPacket.fromScene(scene,
        step/24,size,const {},includeMesh:false);
      expect(packet.interleaved,isEmpty);
      expect(packet.indices,isEmpty);
      sampled+=packet.morphWeights.length+packet.bones.length+
        packet.camera.length;
    }
    watch.stop();
    expect(sampled,24*(8+55*16+20));
    // Diagnostic only: this timer excludes method channels, native raster,
    // battery and actual device FPS; never assert performance on CI runners.
    expect(watch.elapsedMicroseconds,greaterThanOrEqualTo(0));
  },timeout:const Timeout(Duration(minutes:2)));

  test('Seven CC0 v7 motions project GPU-skinned joints like CPU baseline',() {
    final raw=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    const size=Size(320,320);
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(raw,pattern:name);
      for(final elapsed in [0.0,2.0]) {
        final packet=GpuSkinningPacket.fromScene(scene,elapsed,size,const {});
        expect(packet.triangles,scene.triangleCount);
        expect(packet.vertices.length,packet.triangles*3*18);
        expect(packet.bones.length,55*16);
        expect(packet.camera.length,20);
        expect(packet.vertices.every((value)=>value.isFinite),true);
        final payload=packet.encode(const Color(0xFF12181F));
        expect(payload.keys.toSet(),
            {'vertices','bones','camera','background'});
        // Shader references the same joint matrices and camera as Canvas.
        // Compare a sample of vertex projections against the CPU skinning
        // render; compare positions without relying on painter sort order.
        final cpu=scene.frame(elapsed,size,const {});
        final all=cpu.parts
            .expand((p)=>p.positions).toList(growable:false);
        expect(all,isNotEmpty);
        final count=packet.vertices.length~/18;
        for(var i=0;i<count;i+=math.max(1,count~/20)) {
          final actual=projected(packet,i*18,size);
          expect(actual.dx.isFinite&&actual.dy.isFinite,true);
          final matching=all.any((p)=>(p-actual).distance<.10);
          expect(matching,true,
              reason:'$name at t=$elapsed vertex=$i / $actual');
        }
      }
    }
  },timeout:const Timeout(Duration(minutes:4)));

  testWidgets('Disabled GPU pilot remains a Flutter Canvas preview',
      (tester) async {
    final data=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final scene=GlbSkinnedScene.decodeMaster(data,
        pattern:'overhead_reach_bilateral');
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Center(child:NativeGpuSkinnedGlbReview(
        scene:scene,size:320,materials:const {},
        background:const Color(0xFF12181F),
        enabled:false,
      )),
    )));
    expect(find.byType(AndroidView),findsNothing);
    expect(find.byType(UiKitView),findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is CustomPaint &&
        widget.painter is GlbSkinnedPainter),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
