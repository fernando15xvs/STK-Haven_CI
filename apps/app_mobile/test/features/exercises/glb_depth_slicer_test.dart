import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

void main() {
  GlbDrawPart fixture() => const GlbDrawPart(
    [
      Offset(0, 0), Offset(1, 0), Offset(0, 1),
      Offset(0, 0), Offset(1, 0), Offset(0, 1),
    ],
    [
      Color(0xFFB4BBC5), Color(0xFFB4BBC5), Color(0xFFB4BBC5),
      Color(0xFFB4BBC5), Color(0xFFB4BBC5), Color(0xFFB4BBC5),
    ],
    [0, 1, 2, 3, 4, 5],
    3.0,
    'STK_REGION_pectoralis_major',
    depths: [4, 4, 4, 2, 2, 2],
  );

  test('One layer preserves the original fast-path collection', () {
    final parts = [fixture()];
    expect(identical(GlbDepthSlicer.split(parts, 1), parts), true);
  });

  test('Layering retains every index while ordering far triangles first', () {
    final source = fixture();
    final pieces = GlbDepthSlicer.split([source], 6);
    expect(pieces.length, 2);
    expect(pieces[0].depth, greaterThan(pieces[1].depth));
    expect(pieces[0].depth, closeTo(4, .0001));
    expect(pieces[1].depth, closeTo(2, .0001));
    expect(pieces.expand((p) => p.indices).length, source.indices.length);
    expect(pieces.map((p) => p.indices).toList(), [
      [0, 1, 2], [3, 4, 5],
    ]);
    for (final piece in pieces) {
      expect(identical(piece.positions, source.positions), true);
      expect(identical(piece.colors, source.colors), true);
      expect(identical(piece.depths, source.depths), true);
      expect(piece.material, source.material);
    }
  });

  test('Invalid settings and unprojected triangles fail closed', () {
    final source = fixture();
    expect(() => GlbDepthSlicer.split([source], 0), throwsRangeError);
    expect(() => GlbDepthSlicer.split([source], 9), throwsRangeError);
    final missing = GlbDrawPart(
      source.positions, source.colors, source.indices,
      source.depth, source.material,
    );
    expect(() => GlbDepthSlicer.split([missing], 6), throwsFormatException);
    final malformed = GlbDrawPart(
      source.positions, source.colors, [0, 1, 6],
      source.depth, source.material, depths: source.depths,
    );
    expect(() => GlbDepthSlicer.split([malformed], 6),
        throwsFormatException);
  });

  test('Flat depth returns unsliced source to avoid fake draw calls', () {
    final source = fixture();
    final flat = GlbDrawPart(
      source.positions, source.colors, source.indices,
      source.depth, source.material,
      depths: List<double>.filled(6, 4),
    );
    final parts = [flat];
    expect(identical(GlbDepthSlicer.split(parts, 6), parts), true);
  });
}
