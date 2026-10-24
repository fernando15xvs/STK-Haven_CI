import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';
import '../../../tool/anatomical_3d/rigged_anatomy_engine.dart' show V3;

void main() {
  const up = V3(0, 0, 1);
  const points = <V3>[
    V3(0, 0, 0), V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1),
  ];
  const fallback = <V3>[up, up, up, up];

  test('Shared muscle seams use the faces of all material groups', () {
    final normals = GlbPoseNormalBuilder.build(
      points,
      [
        [0, 1, 2], // flat +Z triangle in muscle region A
        [0, 1, 3], // slanted triangle in region B
      ],
      fallback,
    );
    expect(normals.length, 4);
    expect(normals[0].z, closeTo(.70710678, .0001));
    expect(normals[0].y, closeTo(-.70710678, .0001));
    expect(normals[1], normals[0]);
    expect(normals[2].z, closeTo(1, .0001));
  });

  test('Normal direction follows posed triangle not neutral bind mesh', () {
    final neutral = GlbPoseNormalBuilder.build(
      points, [[0, 1, 2]], fallback,
    );
    final deformed = <V3>[
      points[0], points[1], const V3(0, 1, 1), points[3],
    ];
    final bent = GlbPoseNormalBuilder.build(
      deformed, [[0, 1, 2]], fallback,
    );
    expect((neutral[0] - bent[0]).length, greaterThan(.2));
    expect(bent[0].z, greaterThan(.5));
  });

  test('Fallback handles reversed winding and degenerate triangles', () {
    final reverse = GlbPoseNormalBuilder.build(
      points, [[0, 2, 1]], fallback,
    );
    expect(reverse[0].z, closeTo(1, .000001));
    final degenerate = GlbPoseNormalBuilder.build(
      points, [[0, 0, 1]], fallback,
    );
    expect(degenerate[0], up);
  });

  test('Malformed or unsafe face streams fail closed', () {
    expect(
      () => GlbPoseNormalBuilder.build(points, [[0, 1]], fallback),
      throwsFormatException,
    );
    expect(
      () => GlbPoseNormalBuilder.build(points, [[0, 1, 9]], fallback),
      throwsFormatException,
    );
    expect(
      () => GlbPoseNormalBuilder.build(points, [[-1, 1, 2]], fallback),
      throwsFormatException,
    );
    expect(
      () => GlbPoseNormalBuilder.build(points, [[0, 1, 2]], [up]),
      throwsFormatException,
    );
    final invalid = <V3>[
      const V3(double.nan, 0, 0), points[1], points[2], points[3],
    ];
    expect(
      () => GlbPoseNormalBuilder.build(
          invalid, [[0, 1, 2]], fallback),
      throwsFormatException,
    );
  });
}
