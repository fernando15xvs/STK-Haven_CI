import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/glb_mobile_frame_probe.dart';

const patterns = <String>[
  'overhead_reach_bilateral','unilateral_reach_left',
  'unilateral_reach_right','bilateral_elbow_curl',
  'hip_hinge','squat_articulation','split_lunge_left',
];

void main() {
  test('CPU probe percentiles reflect exactly the measured input', () {
    final s=GlbCpuFrameProbe.summarize([600,100,400,200,300],
        maxDrawParts:12,vertices:900,triangles:700);
    expect(s.frames,5);
    expect(s.medianMicroseconds,300);
    expect(s.p95Microseconds,600);
    expect(s.maxMicroseconds,600);
    expect(s.toJson()['measurementScope'],contains('not rendered FPS'));
    expect(()=>GlbCpuFrameProbe.summarize([],
        maxDrawParts:12,vertices:900,triangles:700),
        throwsFormatException);
    expect(()=>GlbCpuFrameProbe.summarize([-1],
        maxDrawParts:12,vertices:900,triangles:700),
        throwsFormatException);
  });

  test('Profile seven real v7 clips without making GPU/FPS promises', () {
    final data=File(
      'build/cc0_master_surface_v7/stk_master_v7_surface_preview.glb',
    ).readAsBytesSync();
    final metrics=<String,Object>{};
    for(final pattern in patterns) {
      final scene=GlbSkinnedScene.decodeMaster(data,pattern:pattern);
      final output=GlbCpuFrameProbe.measure(scene,
          samples:8,size:const Size(320,320));
      expect(output.frames,8);
      expect(output.vertices,scene.vertexCount);
      expect(output.triangles,scene.triangleCount);
      expect(output.medianMicroseconds,greaterThanOrEqualTo(0));
      expect(output.p95Microseconds,greaterThanOrEqualTo(
          output.medianMicroseconds));
      expect(output.maxDrawParts,greaterThan(0));
      metrics[pattern]=output.toJson();
    }
    expect(metrics.length,7);
    final report=<String,Object>{
      'asset':'stk_master_v7_surface_preview.glb',
      'previewOnly':true,'approved':false,'enabled':false,
      'sampleMode':'Flutter test VM, CPU pose and projection, no rendering',
      'notMeasured':[
        'native GPU draw time','device FPS','battery',
        'physical device memory or thermals',
      ],
      'clips':metrics,
    };
    final dir=Directory('build/cc0_master_v7_flutter_qa')
        ..createSync(recursive:true);
    File('${dir.path}/cpu_frame_probe_report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  });
}
