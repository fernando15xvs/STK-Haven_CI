import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_runtime.dart';

const _author='build/cc0_master_surface_v7/v8_authoring/high_res_v914';
const _mobile='build/cc0_master_surface_v7/v8_authoring';
const _exercises=['ex_bench_press','ex_barbell_row','ex_squat'];

void main() {
  test('v9.14 offline high-resolution master cannot bypass 850KiB limit',() {
    final high=File('$_author/stk_master_v914_high_res_authoring.glb')
        .readAsBytesSync();
    final low=File('$_mobile/stk_master_v8_anatomy_preview.glb')
        .readAsBytesSync();
    expect(high.length,greaterThan(850*1024));
    expect(high.length,lessThan(6*1024*1024));
    expect(low.length,lessThanOrEqualTo(850*1024));
    expect(()=>GlbSkinnedScene.decodeMaster(high,
      pattern:'overhead_reach_bilateral'),throwsFormatException);
    final safe=GlbSkinnedScene.decodeMaster(low,
      pattern:'overhead_reach_bilateral');
    expect(safe.containsRigidEquipment,false);
    expect(safe.frame(1,const Size(320,320),const {}).finite,true);
  });

  test('v9.14 three authoring pilots remain disabled by mobile budgets',() {
    for(final id in _exercises) {
      final high=File('$_author/${id}_master55_v914_high_res_qa.glb')
        .readAsBytesSync();
      final low=File('$_mobile/${id}_master55_v8_sculpt_qa.glb')
        .readAsBytesSync();
      expect(high.length,greaterThan(1400*1024));
      expect(low.length,lessThan(1400*1024));
      expect(()=>GlbSkinnedScene.decodeMasterExercise(high,
        exerciseId:id),throwsFormatException);
      final preview=GlbSkinnedScene.decodeMasterExercise(low,
        exerciseId:id);
      expect(preview.containsRigidEquipment,true);
      expect(preview.frame(1,const Size(320,320),const {}).finite,true);
    }
  },timeout:const Timeout(Duration(minutes:3)));
}
