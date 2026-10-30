"""STK Haven v9.42: actual upper-body morphology with locked QA safety."""
import math
import unittest
from pathlib import Path

from retarget_cc0_glb import GLB,EXERCISES
import sculpt_upper_torso_v942 as upper

ROOT=(Path('build/cc0_master_surface_v7/v8_authoring')/
    'detail_bake_v915/torso_v916/hand_v917/contact_v918'/
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925'/
    'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932'/
    'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937'/
    'left_thumb_angle_v938/cuticles_v939/lower_leg_v940/torso_v941')


class UpperTorsoV942Tests(unittest.TestCase):
    def test_pectoralis_upper_and_lower_are_distinct(self):
        hi=upper.chest_subregion_weights(1.)
        lo=upper.chest_subregion_weights(-1.)
        self.assertGreater(hi[0],lo[0])
        self.assertGreater(lo[1],hi[1])
        for a in (hi,lo):
            self.assertAlmostEqual(sum(a),1.)
        self.assertEqual(len(upper.REGIONS),6)

    def test_real_skinned_six_regions_three_disabled_pilots(self):
        self.assertTrue(ROOT.is_dir(),'Missing previous v9.41 QA sources')
        target=ROOT/'upper_v942'
        result=upper.build(ROOT,target)
        self.assertFalse(result['enabled'])
        self.assertFalse(result['approved'])
        self.assertEqual(result['pilotCount'],3)
        for row in result['pilots']:
            exercise=row['exerciseId']
            self.assertIn(exercise,EXERCISES)
            a=GLB((ROOT/(exercise+
                '_v941_torso_volume_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            b=GLB((target/(exercise+
                '_v942_upper_torso_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            self.assertEqual(b.doc['extras']['upperTorsoContourVersion'],942)
            self.assertFalse(b.doc['extras']['approved'])
            self.assertFalse(b.doc['extras']['enabled'])
            for item in ('nodes','skins','animations','meshes','materials'):
                self.assertEqual(a.doc[item],b.doc[item])
            attrs=a.doc['meshes'][0]['primitives'][0]['attributes']
            for item in ('JOINTS_0','WEIGHTS_0'):
                self.assertEqual(a.accessor(attrs[item]),b.accessor(attrs[item]))
            for old,new in zip(
                a.doc['meshes'][0]['primitives'][0]['targets'],
                b.doc['meshes'][0]['primitives'][0]['targets']):
                for channel in old:
                    self.assertEqual(a.accessor(old[channel]),
                                     b.accessor(new[channel]))
            before=a.accessor(attrs['POSITION'])
            after=b.accessor(attrs['POSITION'])
            self.assertTrue(any(math.dist(x,y)>.00000005
                                for x,y in zip(before,after)))
            self.assertEqual(row['jointCount'],55)
            self.assertEqual(row['morphTargets'],8)
            self.assertLessEqual(row['maxAddedDisplacementMeters'],
                upper.MAX_ADDED_DISPLACEMENT_METERS+.000001)
            self.assertLessEqual(row['maxNormalChangeDegrees'],9.001)
            self.assertEqual(row['invertedTriangles'],0)
            for region in upper.REGIONS:
                for side in ('l','r'):
                    self.assertGreaterEqual(
                        row['upperTorsoRegionSamples'][region][side],3)
            for count in row['pectoralisArtGuideSamples'].values():
                self.assertGreaterEqual(count,3)
        self.assertTrue((target/'upper_torso_v942_report.json').is_file())

    def test_guard_approved_unknown_repeated_sources(self):
        source=(ROOT/'ex_squat_v941_torso_volume_mobile_qa.glb').read_bytes()
        tampered=GLB(source,expected_sha=None)
        tampered.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            upper.sculpt(tampered.bytes(),'ex_squat')
        with self.assertRaises(ValueError):
            upper.sculpt(source,'fake_exercise')
        payload,_=upper.sculpt(source,'ex_squat')
        with self.assertRaises(ValueError):
            upper.sculpt(payload,'ex_squat')


if __name__=='__main__':
    unittest.main()
