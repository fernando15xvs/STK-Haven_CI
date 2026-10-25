"""60 Hz actual skinned comparison of unapproved v9.41/v9.42 scenes."""
import math
import unittest
from pathlib import Path

from retarget_cc0_glb import GLB,EXERCISES
import audit_dynamic_torso_v943 as dynamic

SOURCE=(Path('build/cc0_master_surface_v7/v8_authoring')/
    'detail_bake_v915/torso_v916/hand_v917/contact_v918'/
    'skin_v919/hand_v920/topology_v922/palm_v924/web_v925'/
    'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932'/
    'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937'/
    'left_thumb_angle_v938/cuticles_v939/lower_leg_v940/torso_v941')
CANDIDATE=SOURCE/'upper_v942'


class SkinnedTorsoDynamicsV943(unittest.TestCase):
    def test_sampling_includes_both_ends_and_guards_input(self):
        self.assertEqual(dynamic._evenly(list(range(20)),4),[0,6,12,19])
        self.assertEqual(dynamic._evenly([2,3],5),[2,3])
        with self.assertRaises(ValueError):
            dynamic._select([(0,0,0)],[])
        self.assertEqual(dynamic.FRAMES,241)
        self.assertEqual(dynamic.FPS,60)

    def test_actual_three_exercises_241_frames_each(self):
        report=dynamic.build(SOURCE,CANDIDATE,CANDIDATE/'dynamic_v943')
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['enabled'])
        self.assertFalse(report['approved'])
        for row in report['pilots']:
            self.assertIn(row['exerciseId'],EXERCISES)
            self.assertEqual(row['frames'],241)
            self.assertEqual(row['sampleRateHz'],60)
            self.assertEqual(row['skinningJointCount'],55)
            self.assertEqual(row['morphTargetCount'],8)
            self.assertGreater(row['evaluatedSkinVertices'],100)
            self.assertEqual(row['skinningEvaluations'],
                             2*241*row['evaluatedSkinVertices'])
            self.assertGreater(row['changedBindVertices'],12)
            self.assertLessEqual(row['maxAnimatedDisplacementMeters'],
                dynamic.MAX_SKINNED_DISPLACEMENT_METERS + 1e-7)
            self.assertLessEqual(row['maxBarProximityChangeMeters'],
                dynamic.MAX_SDF_REGRESSION_METERS + 1e-7)
            self.assertLessEqual(row['maxBenchProximityChangeMeters'],
                dynamic.MAX_SDF_REGRESSION_METERS + 1e-7)
            self.assertAlmostEqual(
                row['maxUnchangedSurfaceDriftMeters'],0.,places=6)
            self.assertTrue(row['rigAndEquipmentUnchanged'])
            self.assertFalse(row['fullSurfaceCollisionCertified'])
        self.assertTrue((CANDIDATE/'dynamic_v943'/
            'dynamic_torso_v943_report.json').is_file())

    def test_approved_repeated_and_wrong_id_rejected(self):
        exercise='ex_squat'
        a=(SOURCE/(exercise+
            '_v941_torso_volume_mobile_qa.glb')).read_bytes()
        b=(CANDIDATE/(exercise+
            '_v942_upper_torso_mobile_qa.glb')).read_bytes()
        with self.assertRaises(ValueError):
            dynamic.review(a,b,'not_an_exercise')
        forged=GLB(b,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            dynamic.review(a,forged.bytes(),exercise)
        with self.assertRaises(ValueError):
            dynamic.review(b,a,exercise)
        with self.assertRaises(ValueError):
            dynamic.review(a,a,exercise)


if __name__=='__main__':
    unittest.main()
