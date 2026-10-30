"""Independent non-production v10.4 anatomical volume and art QA gates."""
from __future__ import annotations
import hashlib
from pathlib import Path
import tempfile
import unittest
import numpy as np
import trimesh
from sculpt_arms_hands_v103 import generate as generate_v103, shaped_arms
from sculpt_aesthetic_lower_body_v104 import (
    AESTHETIC_OVERRIDES, ARM_CUT_STRENGTH, TORSO_CUT_STRENGTH,
    build, generate, shaped_aesthetic,
)


class AthleticProportionsV104Test(unittest.TestCase):
    def test_all_volumes_bilateral_and_face_unexaggerated(self):
        newer,altered=shaped_aesthetic()
        previous,*_=shaped_arms()
        self.assertEqual(len(newer),len(previous))
        self.assertEqual(len(newer),106)
        self.assertGreater(len(altered),65)
        atlas={v.region:v for v in newer}
        for key in ('gluteus_maximus','thigh','vastus_lateralis',
                    'gastrocnemius_medial','pectoral_major',
                    'deltoid_lateral','upper_arm','wrist'):
            left=atlas['left_'+key]
            right=atlas['right_'+key]
            self.assertAlmostEqual(left.center_x,-right.center_x)
            for dim in ('radius_x','radius_y','radius_z'):
                self.assertAlmostEqual(getattr(left,dim),getattr(right,dim))
        old={v.region:v for v in previous}
        for key in ('left_gluteus_maximus','right_thigh',
                    'left_gastrocnemius_lateral','left_deltoid_lateral',
                    'right_pectoral_major'):
            self.assertLess(atlas[key].radius_z,old[key].radius_z)
        self.assertLess(TORSO_CUT_STRENGTH,.5)
        self.assertLess(ARM_CUT_STRENGTH,.5)
        self.assertEqual(len(AESTHETIC_OVERRIDES),len(set(AESTHETIC_OVERRIDES)))

    def test_mesh_rebalances_a_real_glb_while_retaining_closed_surface(self):
        a,*_=generate_v103(.018)
        b,*_=generate(.018)
        self.assertTrue(b.is_watertight)
        self.assertTrue(b.is_winding_consistent)
        self.assertEqual(len(b.split(only_watertight=False)),1)
        # A deliberately obvious 5%+ visual silhouette mass change,
        # rather than the invisible millimeter nudges of v9.
        self.assertLess(b.volume/a.volume,.95)
        self.assertGreater(b.volume/a.volume,.78)
        def max_leg_span(mesh,y):
            v=mesh.vertices
            layer=v[(np.abs(v[:,1]-y)<.018)&(np.abs(v[:,0])<.42)]
            self.assertGreater(len(layer),15)
            return np.percentile(np.abs(layer[:,0]),90)
        self.assertLess(max_leg_span(b,.31),max_leg_span(a,.31))
        self.assertLess(max_leg_span(b,.69),max_leg_span(a,.69))
        self.assertGreater(b.bounds[1,1]-b.bounds[0,1],1.80)
        self.assertLess(b.bounds[1,1]-b.bounds[0,1],1.93)

    def test_export_is_real_safe_disabled_and_sha_pinned(self):
        with tempfile.TemporaryDirectory() as d:
            mesh,report=build(d,.018)
            path=Path(d)/report['glb']['filename']
            raw=path.read_bytes()
            imported=trimesh.load(path,force='mesh')
            self.assertEqual(hashlib.sha256(raw).hexdigest(),
                             report['glb']['sha256'])
            self.assertTrue(imported.is_watertight)
            self.assertEqual(len(imported.faces),len(mesh.faces))
            self.assertEqual(report['mesh']['components'],1)
            self.assertEqual(report['volumeCount'],106)
            self.assertEqual(report['parentVersion'],103)
            self.assertEqual(report['masterVersion'],104)
            self.assertEqual(report['catalogCount'],229)
            self.assertEqual(report['catalogApproved'],0)
            self.assertEqual(report['catalogEnabled'],0)
            for field in ('approved','enabled','productionReady','rigged',
                          'animated','uvComplete','manualArtistApproved',
                          'anatomyCertified','reviewedOnPhysicalDevice'):
                self.assertIs(report[field],False)

    def test_invalid_pitch_rejected(self):
        for pitch in (.002,.008,.019,.05):
            with self.assertRaises(ValueError):
                generate(pitch)


if __name__=='__main__':
    unittest.main()
