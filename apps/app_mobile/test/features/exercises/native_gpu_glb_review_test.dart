import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/native_gpu_glb_review.dart';

void main() {
  test('Native GPU packet expands triangles and preserves per-vertex depth',() {
    final far=GlbDrawPart(
      const [Offset(40,40),Offset(240,40),Offset(40,240)],
      const [Color(0xFF2962FF),Color(0xFF2962FF),Color(0xFF2962FF)],
      const [0,1,2],4.0,'STK_REGION_pectoralis_major',
      depths:const [4.0,4.0,4.0],
    );
    final near=GlbDrawPart(
      const [Offset(80,80),Offset(200,80),Offset(80,200)],
      const [Color(0xFFC2410C),Color(0xFFC2410C),Color(0xFFC2410C)],
      const [0,1,2],2.0,'STK_REGION_deltoid',
      depths:const [2.0,2.0,2.0],
    );
    final frame=GlbDrawFrame([far,near],6,2);
    final packet=GpuReviewPacket.fromFrame(frame,const Size(320,320));
    expect(packet.triangleCount,2);
    expect(packet.vertices.length,42);
    expect(packet.vertices[0],closeTo(-.75,1e-6));
    expect(packet.vertices[1],closeTo(.75,1e-6));
    expect(packet.vertices[2],greaterThan(packet.vertices[23]));
    expect(packet.vertices[3],closeTo(41/255,1e-6));
    expect(packet.vertices[4],closeTo(98/255,1e-6));
    expect(packet.vertices[5],closeTo(1,1e-6));
    expect(packet.vertices[6],closeTo(1,1e-6));
    final draw=NativeGpuReviewDraw(packet:packet,
        background:const Color(0xFF12181F)).encode();
    expect(draw['vertices'],isA<Float32List>());
    expect((draw['background'] as Float32List).length,4);
  });

  test('Corrupt native depth packet fails closed before platform invocation',() {
    final invalid=GlbDrawPart(
      const [Offset(0,0),Offset(1,0),Offset(0,1)],
      const [Color(0xFFFFFFFF),Color(0xFFFFFFFF),
             Color(0xFFFFFFFF)],
      const [0,1,2],1,'STK_BODY',
    );
    expect(()=>GpuReviewPacket.fromFrame(
      GlbDrawFrame([invalid],3,1),const Size(320,320)),
      throwsFormatException);
    final unsafe=GlbDrawPart(
      invalid.positions,invalid.colors,const [0,1,9],
      1,'STK_BODY',depths:const [1,1,1],
    );
    expect(()=>GpuReviewPacket.fromFrame(
      GlbDrawFrame([unsafe],3,1),const Size(320,320)),
      throwsFormatException);
    expect(()=>GpuReviewPacket.fromFrame(
      GlbDrawFrame([invalid],3,1),const Size(0,320)),
      throwsFormatException);
  });

  test('V7 real master GPU packet stays bounded and keeps all triangles',() {
    final bytes=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final names=<String>[
      'overhead_reach_bilateral','unilateral_reach_left',
      'unilateral_reach_right','bilateral_elbow_curl',
      'hip_hinge','squat_articulation','split_lunge_left',
    ];
    for(final name in names) {
      final scene=GlbSkinnedScene.decodeMaster(bytes,pattern:name);
      final frame=scene.frame(2,const Size(320,320),const {},
          poseNormals:true,depthSlices:1);
      final packet=GpuReviewPacket.fromFrame(frame,const Size(320,320));
      expect(packet.triangleCount,scene.triangleCount);
      expect(packet.vertices.length,scene.triangleCount*3*gpuReviewStride);
      expect(packet.vertices.length,lessThanOrEqualTo(
        maxGpuReviewTriangles*3*gpuReviewStride));
      expect(packet.vertices.every((v)=>v.isFinite),true);
    }
  });
}
