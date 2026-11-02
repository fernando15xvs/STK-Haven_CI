"""Seven motion clips and all morph deltas survive the offline mobile LOD."""
import json,math,os,unittest
from pathlib import Path
from retarget_cc0_glb import GLB

BASE=Path(os.environ.get('STK_MASTER_MOTION_V3','build/cc0_master_motion_v3'))
OUT=Path(os.environ.get('STK_MASTER_MOBILE_V4','build/cc0_master_mobile_v4'))
class MasterMobileV4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=GLB((BASE/'stk_master_55_motion_lab_v3_unapproved.glb').read_bytes(),expected_sha=None)
        cls.lod=GLB((OUT/'stk_master_v4_mobile_morph_lod_unapproved.glb').read_bytes(),expected_sha=None)
        cls.report=json.loads((OUT/'mobile_master_v4_report.json').read_text())
    def test_mobile_asset_is_bounded_and_unapproved(self):
        r=self.report;doc=self.lod.doc
        self.assertLess(r['lodBytes'],850*1024)
        self.assertLess(r['ratio'],.10)
        self.assertLess(r['maxClusterErrorMeters'],.035)
        self.assertTrue(2000<r['vertices']<10000)
        self.assertLess(r['triangles'],25000)
        self.assertEqual((r['jointCount'],r['clipCount'],r['morphTargetCount']),
                         (55,7,8))
        self.assertEqual(r['catalogCount'],229)
        self.assertFalse(r['approved']);self.assertFalse(r['enabled'])
        self.assertFalse(doc['extras']['approved'])
        self.assertEqual(len(doc['animations']),7)
        self.assertEqual(len(doc['meshes'][0]['primitives']),12)
        self.assertEqual(self.base.doc['nodes'],doc['nodes'])
        self.assertEqual(self.base.doc['skins'][0]['joints'],doc['skins'][0]['joints'])
    def test_regions_are_distinct_and_morphs_remain_active(self):
        src=self.base.doc['meshes'][0];dst=self.lod.doc['meshes'][0]
        self.assertEqual(src['extras']['targetNames'],dst['extras']['targetNames'])
        self.assertEqual(dst['weights'],[0.]*8)
        for region in dst['primitives']:
            self.assertEqual(region['attributes'],dst['primitives'][0]['attributes'])
            self.assertEqual(region['targets'],dst['primitives'][0]['targets'])
            self.assertEqual(len(region['targets']),8)
            self.assertGreater(len(self.lod.accessor(region['indices'])),30)
        for ratio in self.report['morphAmplitudeRatios']:
            self.assertGreater(ratio,.88);self.assertLess(ratio,1.08)
        for target in dst['primitives'][0]['targets']:
            self.assertTrue(any(max(abs(x) for x in vertex)>1e-5
                 for vertex in self.lod.accessor(target['POSITION'])))
    def test_animation_samples_and_inverse_binds_are_exact(self):
        src=self.base.doc;dst=self.lod.doc
        for first,second in zip(src['animations'],dst['animations']):
            self.assertEqual(first['name'],second['name'])
            self.assertEqual(first['channels'],second['channels'])
            for a,b in zip(first['samplers'],second['samplers']):
                self.assertEqual(a['interpolation'],b['interpolation'])
                self.assertEqual(self.base.accessor(a['input']),
                                 self.lod.accessor(b['input']))
                self.assertEqual(self.base.accessor(a['output']),
                                 self.lod.accessor(b['output']))
        self.assertEqual(self.base.accessor(src['skins'][0]['inverseBindMatrices']),
                         self.lod.accessor(dst['skins'][0]['inverseBindMatrices']))
if __name__=='__main__':unittest.main()
