"""Tests of real new v10.2 static GLB; no automatic art approval."""
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
import trimesh

from sculpt_torso_back_v102 import (
    _incision, _surface_anatomy, build, generate, shaped_volumes,
    REGIONS_RESHAPED,
)


class TorsoBackBlock2Tests(unittest.TestCase):
    def test_named_anatomy_and_symmetric_bilateral_regions(self):
        regions,modified=shaped_volumes()
        self.assertEqual(len(regions),92)
        self.assertEqual(len(modified),20)
        names={item.region:item for item in regions}
        self.assertEqual(len(names),len(regions))
        for region in REGIONS_RESHAPED:
            l=names['left_'+region]
            r=names['right_'+region]
            self.assertEqual(l.center_x,-r.center_x)
            self.assertEqual(l.radius_x,r.radius_x)
            self.assertEqual(l.radius_y,r.radius_y)
            self.assertEqual(l.radius_z,r.radius_z)

    def test_real_depth_front_back_and_invalid_grooves(self):
        axes=[np.linspace(-.45,.45,91,dtype=np.float32),
              np.linspace(.95,1.60,66,dtype=np.float32),
              np.linspace(-.30,.30,61,dtype=np.float32)]
        field=np.zeros(tuple(len(a) for a in axes),dtype=np.float32)
        strokes=_surface_anatomy(field,axes)
        self.assertEqual(len(strokes),35)
        self.assertGreater(float(field[:,:,axes[2]>.12].max()),.002)
        self.assertGreater(float(field[:,:,axes[2]<-.12].max()),.002)
        original=field.copy()
        for depth,width,side in ((.50,.01,'front'),(.008,.031,'front'),
                                  (.008,.01,'side')):
            with self.assertRaises(ValueError):
                _incision(field,axes,(0,1),(1,2),depth,width,side)
        np.testing.assert_array_equal(field,original)

    def test_real_glb_is_watertight_and_quarantined(self):
        with tempfile.TemporaryDirectory() as root:
            master,report=build(Path(root),pitch=.018)
            path=Path(root)/report['glb']['filename']
            self.assertTrue(path.exists())
            reread=trimesh.load(path,force='mesh')
            self.assertTrue(master.is_watertight)
            self.assertTrue(reread.is_watertight)
            self.assertTrue(reread.is_winding_consistent)
            self.assertGreater(len(reread.faces),20000)
            self.assertGreater(reread.volume,.15)
            self.assertEqual(report['torsoIncisionCount'],35)
            self.assertEqual(report['catalogTotal'],229)
            self.assertEqual(report['exercisesApproved'],0)
            self.assertTrue(report['sourceMasterV10Frozen'])
            for key in ('animated','rigged','approved','enabled',
                        'productionReady','manualArtistApproval'):
                self.assertIs(report[key],False)
            self.assertEqual(report,json.loads((Path(root)/
                'stk_master_v102_torso_back_report.json').read_text()))

    def test_mesh_pitch_bounds(self):
        with self.assertRaises(ValueError):
            generate(.002)
        with self.assertRaises(ValueError):
            generate(.030)


if __name__=='__main__':
    unittest.main()
