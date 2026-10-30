import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_camera.dart';

void main() {
  test('Finger orbit traverses full 360 degrees and wraps continuously', () {
    const pose=GlbCameraPose();
    expect(pose.isDefault,true);
    final quarter=pose.drag((math.pi/2)/
        GlbCameraPose.radiansPerHorizontalPixel,0);
    expect(quarter.yaw,closeTo(math.pi/2,1e-6));
    final full=pose.drag((2*math.pi)/
        GlbCameraPose.radiansPerHorizontalPixel,0);
    expect(full.yaw,closeTo(0,1e-6));
    final backwards=pose.drag((-2*math.pi)/
        GlbCameraPose.radiansPerHorizontalPixel,0);
    expect(backwards.yaw,closeTo(0,1e-6));
    expect(pose.isDefault,true);
  });

  test('Vertical swipe enforces comfortable elevation range', () {
    const pose=GlbCameraPose();
    expect(pose.drag(0,-100).elevation,closeTo(.4,1e-9));
    expect(pose.drag(0,-100000).elevation,
        GlbCameraPose.maxElevation);
    expect(pose.drag(0,100000).elevation,
        GlbCameraPose.minElevation);
  });

  test('Pinch and accessible buttons clamp camera distance', () {
    const pose=GlbCameraPose();
    expect(pose.scale(2,initialZoom:1).zoom,GlbCameraPose.minZoom);
    expect(pose.scale(.01,initialZoom:1).zoom,
        GlbCameraPose.maxZoom);
    expect(pose.zoomButton(true).zoom,closeTo(.85,1e-9));
    expect(pose.zoomButton(false).zoom,closeTo(1.15,1e-9));
    final updated=pose.drag(100,0).zoomButton(true);
    expect(updated.yaw,isNot(0));
    expect(updated.zoom,lessThan(1));
    expect(const GlbCameraPose().isDefault,true);
  });

  test('Malformed gesture parameters are safely rejected', () {
    const pose=GlbCameraPose();
    expect(()=>pose.drag(double.nan,0),throwsFormatException);
    expect(()=>pose.drag(0,double.infinity),throwsFormatException);
    expect(()=>pose.scale(0,initialZoom:1),throwsFormatException);
    expect(()=>pose.scale(double.nan,initialZoom:1),
        throwsFormatException);
  });
}
