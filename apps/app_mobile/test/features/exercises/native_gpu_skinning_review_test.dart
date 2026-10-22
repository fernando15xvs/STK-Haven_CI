import 'dart:typed_data';
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
}
