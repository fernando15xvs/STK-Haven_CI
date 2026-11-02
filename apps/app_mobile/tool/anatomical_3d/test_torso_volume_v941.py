"""STK Haven v9.41: verify real torso POSITION edits and strict quarantine."""
import math
import unittest
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES
import sculpt_torso_volume_v941 as torso
from build_torso_contours_v916 import contour_fields

ROOT = (Path('build/cc0_master_surface_v7/v8_authoring')
    / 'detail_bake_v915/torso_v916/hand_v917/contact_v918'
    / 'skin_v919/hand_v920/topology_v922/palm_v924/web_v925'
    / 'two_joint_v929/knuckle_v930/fold_v931/nail_bed_v932'
    / 'nail_plates_v933/offset_v935/lod_v936/thumb_fit_v937'
    / 'left_thumb_angle_v938/cuticles_v939/lower_leg_v940')


class TorsoVolumeV941Tests(unittest.TestCase):
    def test_artistic_fields_are_front_only_and_bilateral(self):
        for x in (-.15,.15):
            fields = contour_fields((x,1.20,.16),(0,0,1))
            self.assertGreater(fields['serratus_anterior'],0)
            rear = contour_fields((x,1.20,.16),(0,0,-1))
            self.assertAlmostEqual(rear['serratus_anterior'],0)
        self.assertEqual(len(torso.AMPLITUDE),3)
        self.assertEqual(len(torso.SPINE_BONES),3)

    def test_actual_three_skinned_master_exercises(self):
        self.assertTrue(ROOT.is_dir(),'v9.40 generated source missing')
        output = ROOT/'torso_v941'
        report = torso.build(ROOT,output)
        self.assertEqual(report['pilotCount'],3)
        self.assertFalse(report['approved'])
        for row in report['pilots']:
            exercise = row['exerciseId']
            self.assertIn(exercise,EXERCISES)
            before = GLB((ROOT/(exercise+
                '_v940_lower_leg_anatomy_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            after = GLB((output/(exercise+
                '_v941_torso_volume_mobile_qa.glb')).read_bytes(),
                expected_sha=None)
            self.assertEqual(after.doc['extras']['torsoVolumeVersion'],941)
            self.assertFalse(after.doc['extras']['approved'])
            self.assertFalse(after.doc['extras']['enabled'])
            for field in ('nodes','skins','animations','meshes','materials'):
                self.assertEqual(before.doc[field],after.doc[field])
            attrs = before.doc['meshes'][0]['primitives'][0]['attributes']
            unchanged = ['JOINTS_0','WEIGHTS_0']
            for attr in unchanged:
                self.assertEqual(before.accessor(attrs[attr]),
                                 after.accessor(attrs[attr]))
            for a,b in zip(before.doc['meshes'][0]['primitives'][0]['targets'],
                           after.doc['meshes'][0]['primitives'][0]['targets']):
                for channel in a:
                    self.assertEqual(before.accessor(a[channel]),
                                     after.accessor(b[channel]))
            positions_old = before.accessor(attrs['POSITION'])
            positions_new = after.accessor(attrs['POSITION'])
            self.assertTrue(any(math.dist(a,b) > .00000005
                for a,b in zip(positions_old,positions_new)))
            self.assertLessEqual(row['maximumTorsoDisplacementMeters'],
                                 torso.MAX_TORSO_DISPLACEMENT_METERS+.000001)
            self.assertLessEqual(row['maximumNormalChangeDegrees'],9.001)
            self.assertEqual(row['flippedTriangles'],0)
            self.assertEqual(row['jointCount'],55)
            self.assertEqual(row['morphTargets'],8)
            for side in ('left','right'):
                for group in torso.ARTIST_GROUPS:
                    self.assertGreaterEqual(
                        row['bilateralContourSamples'][side][group],3)
        self.assertTrue((output/'torso_volume_v941_report.json').exists())

    def test_rejects_approved_repeated_and_wrong_exercise(self):
        exercise='ex_squat'
        raw=(ROOT/(exercise+
            '_v940_lower_leg_anatomy_mobile_qa.glb')).read_bytes()
        forged=GLB(raw,expected_sha=None)
        forged.doc['extras']['approved']=True
        with self.assertRaises(ValueError):
            torso.sculpt(forged.bytes(),exercise)
        with self.assertRaises(ValueError):
            torso.sculpt(raw,'fake_id')
        processed,_=torso.sculpt(raw,exercise)
        with self.assertRaises(ValueError):
            torso.sculpt(processed,exercise)


if __name__=='__main__':
    unittest.main()
