"""Safety tests for the non-production v10.3 arm/hand sculpt."""
from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest

import numpy as np
from scipy.spatial import cKDTree
import trimesh

from sculpt_arms_hands_v103 import (
    ARM_PARAMETERS, DIGIT_SPECS, _arm_channels, build, generate,
    shaped_arms,
)
from sculpt_torso_back_v102 import generate as generate_v102


class ArmsHandsSculptTests(unittest.TestCase):
    def test_arms_and_fingers_are_bilateral_and_distinct(self):
        volumes,changed,torso=shaped_arms()
        self.assertEqual(len(volumes),106)
        self.assertEqual(len(changed),32)
        self.assertEqual(len(torso),20)
        names={v.region:v for v in volumes}
        self.assertEqual(len(names),len(volumes))
        for region in ARM_PARAMETERS:
            left,right=names['left_'+region],names['right_'+region]
            self.assertEqual(left.center_x,-right.center_x)
            self.assertEqual(left.radius_x,right.radius_x)
            self.assertEqual(left.radius_y,right.radius_y)
            self.assertEqual(left.radius_z,right.radius_z)
        for digit in range(4):
            left=names['left_finger_'+str(digit)]
            right=names['right_finger_'+str(digit)]
            self.assertEqual(left.center_x,-right.center_x)
            self.assertGreater(left.radius_y,left.radius_x*3)
            self.assertNotEqual(left.center_x,0)
        self.assertEqual(len(DIGIT_SPECS),4)
        for side in ('left','right'):
            for name in ['thenar_eminence','hypothenar','thumb_distal']:
                self.assertIn(side+'_'+name,names)

    def test_actual_arm_geometry_changes_but_torso_is_preserved(self):
        original,*_=generate_v102(.018)
        sculpted,*_=generate(.018)
        self.assertTrue(sculpted.is_watertight)
        self.assertTrue(sculpted.is_winding_consistent)
        self.assertEqual(len(sculpted.split(only_watertight=False)),1)
        vertices=sculpted.vertices
        tree=cKDTree(original.vertices)
        hands=(np.abs(vertices[:,0])>.73)&(vertices[:,1]>.65)&(vertices[:,1]<.98)
        arms=(np.abs(vertices[:,0])>.43)&(vertices[:,1]>.98)&(vertices[:,1]<1.47)
        torso=(np.abs(vertices[:,0])<.20)&(vertices[:,1]>1.1)&(vertices[:,1]<1.5)
        self.assertGreater(int(hands.sum()),70)
        self.assertGreater(int(arms.sum()),200)
        changed=tree.query(vertices[hands|arms])[0]
        preserved=tree.query(vertices[torso])[0]
        # Changes must be tangible at centimetre scale, unlike v9 micromorphs.
        self.assertGreater(float(np.percentile(changed,90)),.007)
        # Identical SDF torso source and tessellation preserves unchanged form.
        self.assertLess(float(np.percentile(preserved,95)),.002)

    def test_real_mesh_glb_provenance_and_release_is_blocked(self):
        with tempfile.TemporaryDirectory() as root:
            mesh,report=build(Path(root),.018)
            path=Path(root)/report['glb']['filename']
            binary=path.read_bytes()
            imported=trimesh.load(path,force='mesh')
            self.assertTrue(mesh.is_watertight)
            self.assertTrue(imported.is_watertight)
            self.assertEqual(len(imported.split(only_watertight=False)),1)
            self.assertEqual(hashlib.sha256(binary).hexdigest(),
                             report['glb']['sha256'])
            self.assertEqual(report['mesh']['triangles'],len(imported.faces))
            self.assertEqual(len(report['armChannels']),8)
            self.assertEqual(report['torsoLinesPreserved'],35)
            self.assertEqual(report['anatomyRegions'],106)
            self.assertEqual(report['catalogExercises'],229)
            self.assertEqual(report['catalogEnabled'],0)
            for key in ('approved','enabled','productionReady',
                        'skinRigComplete','handGripTopologyFinished',
                        'manualCharacterArtistReviewed'):
                self.assertIs(report[key],False)

    def test_unsafe_pitch_is_rejected(self):
        for value in (.001,.006,.020):
            with self.assertRaises(ValueError):
                generate(value)


if __name__=='__main__':
    unittest.main()