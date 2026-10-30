import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'anatomical_glb_runtime.dart';

/// CPU-only development benchmark for deciding when native GPU skinning is
/// needed. These timings do NOT measure GPU rasterization, real FPS, memory
/// pressure or battery on iOS/Android hardware.
class GlbCpuFrameSample {
  const GlbCpuFrameSample({
    required this.frames,
    required this.medianMicroseconds,
    required this.p95Microseconds,
    required this.maxMicroseconds,
    required this.maxDrawParts,
    required this.vertices,
    required this.triangles,
  });

  final int frames,medianMicroseconds,p95Microseconds,maxMicroseconds;
  final int maxDrawParts,vertices,triangles;

  Map<String,Object> toJson() => {
    'frames':frames,
    'medianCpuUs':medianMicroseconds,
    'p95CpuUs':p95Microseconds,
    'maxCpuUs':maxMicroseconds,
    'maxDrawParts':maxDrawParts,
    'vertices':vertices,
    'triangles':triangles,
    'measurementScope':'Flutter test VM CPU pose/projection only; '
      'not rendered FPS, GPU frame time or battery',
  };
}

class GlbCpuFrameProbe {
  static GlbCpuFrameSample summarize(List<int> samples,
      {required int maxDrawParts,required int vertices,
       required int triangles}) {
    if(samples.isEmpty||samples.length>300||
       samples.any((s)=>s<0)||maxDrawParts<=0||
       vertices<=0||triangles<=0) {
      throw const FormatException('Invalid 3D CPU probe data');
    }
    final times=List<int>.of(samples)..sort();
    final count=times.length;
    final middle=count~/2;
    final median=count.isOdd?times[middle]:
        (times[middle-1]+times[middle])~/2;
    final p95=times[(math.max(1,(count*.95).ceil())-1)
        .clamp(0,count-1).toInt()];
    return GlbCpuFrameSample(
      frames:count,medianMicroseconds:median,p95Microseconds:p95,
      maxMicroseconds:times.last,maxDrawParts:maxDrawParts,
      vertices:vertices,triangles:triangles,
    );
  }

  static GlbCpuFrameSample measure(GlbSkinnedScene scene,
      {int samples=12,Size size=const Size(320,320),
       bool dark=true}) {
    if(samples<3||samples>120||
       !size.width.isFinite||!size.height.isFinite||
       size.width<100||size.height<100) {
      throw const FormatException('Unsafe offline CPU probe configuration');
    }
    final times=<int>[];
    var maxParts=0;
    // Warm once to avoid charging the first sample for Dart/JIT setup.
    scene.frame(0,size,const <String,Color>{},dark:dark);
    for(var i=0;i<samples;i++) {
      final timer=Stopwatch()..start();
      final frame=scene.frame(
        scene.durationSeconds*i/samples,
        size,const <String,Color>{},dark:dark,
      );
      timer.stop();
      if(!frame.finite||frame.vertices!=scene.vertexCount||
         frame.triangles!=scene.triangleCount) {
        throw const FormatException('Invalid 3D CPU frame geometry');
      }
      maxParts=math.max(maxParts,frame.parts.length);
      times.add(timer.elapsedMicroseconds);
    }
    return summarize(times,maxDrawParts:maxParts,
      vertices:scene.vertexCount,triangles:scene.triangleCount);
  }
}
