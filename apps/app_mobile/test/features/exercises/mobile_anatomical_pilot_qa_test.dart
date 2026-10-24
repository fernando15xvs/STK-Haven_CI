import 'package:flutter_test/flutter_test.dart';

import '../../../tool/anatomical_3d/anatomical_glb_staging.dart';
import '../../../tool/anatomical_3d/anatomical_pilot_review_qa.dart';

void main() {
  test('v9.7 only the three historical exercise pilots are in review',() {
    final plans=AnatomicalPilotQaPlan.cases;
    expect(plans.keys.toSet(),AnatomicalGlbStaging.stableIds);
    final all=<String>{};
    for(final entry in plans.entries) {
      final p=entry.value;
      expect(p.exerciseId,entry.key);
      expect(p.title,isNotEmpty);
      expect(p.equipment,isNotEmpty);
      expect(p.hasValidRegions,true);
      expect(p.checks.length,greaterThanOrEqualTo(5));
      expect(p.checks.every((c)=>c.length>18),true);
      all.addAll(p.primaryRegions);
      all.addAll(p.secondaryRegions);
      expect(p.isApproved,false);
      expect(p.isEnabled,false);
      final record=p.toReviewJson();
      expect(record['approved'],false);
      expect(record['enabled'],false);
      expect(record['anatomicalExpertReviewed'],false);
      expect(record['physicalDeviceReviewed'],false);
      expect(record['equipment'],p.equipment);
    }
    expect(all.contains('pectoralis_major'),true);
    expect(all.contains('latissimus_dorsi'),true);
    expect(all.contains('quadriceps_femoris'),true);
    expect(all.every(AnatomicalGlbStaging.masterRegionNames.contains),true);
  });

  test('v9.7 review metadata cannot silently approve arbitrary anatomy',() {
    final invalid=AnatomicalPilotQaPlan(
      exerciseId:'ex_bench_press',title:'QA fixture',equipment:'bench',
      primaryRegions:{'unknown_anatomical_surface'},
      secondaryRegions:{'pectoralis_major'},
      checks:const ['manual only'],
    );
    expect(invalid.hasValidRegions,false);
    expect(invalid.isApproved,false);
    expect(invalid.isEnabled,false);
  });
}
