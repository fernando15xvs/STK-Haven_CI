"""Tests for the brand-new NON-production v10 anatomical authoring master."""
import json
import math
from pathlib import Path
import tempfile
import unittest
import trimesh

from build_master_silhouette_v10 import AnatomyVolume, master_landmarks, volumes, build


class NewMasterSilhouetteTests(unittest.TestCase):
    def test_landmark_ratios_and_bilateral_symmetry(self):
        landmarks=master_landmarks()
        self.assertGreater(len(landmarks),14)
        shoulder=landmarks['right_shoulder'][0]-landmarks['left_shoulder'][0]
        hip=landmarks['right_hip'][0]-landmarks['left_hip'][0]
        self.assertGreater(shoulder/hip,1.9)
        self.assertLess(shoulder/hip,2.5)
        for name in ['shoulder','elbow','wrist','hip','knee','ankle']:
            left=landmarks['left_'+name]
            right=landmarks['right_'+name]
            self.assertAlmostEqual(left[0],-right[0],places=7)
            self.assertAlmostEqual(left[1],right[1],places=7)
            self.assertAlmostEqual(left[2],right[2],places=7)

    def test_distinct_anatomy_and_mirror_volumes(self):
        parts=volumes()
        self.assertGreaterEqual(len(parts),80)
        named={p.region:p for p in parts}
        self.assertEqual(len(named),len(parts))
        for stem in ['pectoral_major','deltoid_lateral','latissimus_dorsi',
                     'rhomboid','rectus_abdominis_1','biceps_brachii',
                     'triceps','gluteus_maximus','rectus_femoris',
                     'hamstrings','gastrocnemius_medial','foot_toes']:
            a=named['left_'+stem]
            b=named['right_'+stem]
            self.assertAlmostEqual(a.center_x,-b.center_x)
            self.assertAlmostEqual(a.center_y,b.center_y)
            self.assertAlmostEqual(a.center_z,b.center_z)
            self.assertAlmostEqual(a.rotation_xy,-b.rotation_xy)
            self.assertAlmostEqual(a.radius_x,b.radius_x)
        with self.assertRaises(ValueError):
            AnatomyVolume('broken',0,0,0,0,.1,.1)
        with self.assertRaises(ValueError):
            AnatomyVolume('broken',0,0,0,.1,.1,.1,blend=.5)

    def test_real_qa_glb_exists_and_cannot_be_approved(self):
        # Coarse mesh for CI; use --pitch=.008 for artist review quality.
        with tempfile.TemporaryDirectory() as temp:
            mesh,report=build(Path(temp),pitch=.018)
            path=Path(temp)/'stk_master_v10_silhouette_unapproved.glb'
            self.assertTrue(path.is_file())
            mesh_again=trimesh.load(path,force='mesh')
            self.assertTrue(mesh.is_watertight)
            self.assertTrue(mesh_again.is_watertight)
            self.assertGreater(len(mesh.faces),4000)
            self.assertGreater(mesh.volume,.02)
            self.assertEqual(report['anatomicalRegions'],len(volumes()))
            self.assertEqual(report['catalogExercisesEnabled'],0)
            for key in ('approved','enabled','skinned','animated',
                        'productionReady','topologyArtistReviewed'):
                self.assertIs(report[key],False)
            self.assertEqual(report['reviewViews'],
                ['front','back','profile','three_quarter'])
            self.assertNotIn('v9.42',report['source'])
            stored=json.loads((Path(temp)/
                'stk_master_v10_silhouette_report.json').read_text())
            self.assertEqual(report,stored)


if __name__=='__main__':
    unittest.main()