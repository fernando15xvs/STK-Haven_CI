"""CC0 licensed mesh retarget gates: no unreviewed asset can ship."""
import json
import math
import os
from pathlib import Path
import struct
import unittest
import retarget_cc0_glb as rig


BASE=Path(os.environ.get('STK_CC0_MODEL','build/cc0_model_stage/human-base-rigged-cc0.glb'))
OUTPUT=Path(os.environ.get('STK_CC0_RETARGET','build/cc0_53bone_retarget'))


def decode(path):
    data=path.read_bytes()
    n,kind=struct.unpack_from('<I4s',data,12)
    if kind!=b'JSON':raise AssertionError('Missing GLB JSON')
    return data,json.loads(data[20:20+n])

class CC0RetargetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not BASE.is_file():raise AssertionError('Missing verified CC0 source in public CI')
        cls.raw=BASE.read_bytes()
        cls.base=rig.GLB(cls.raw)
        if not OUTPUT.is_dir():raise AssertionError('CC0 retarget pipeline was not executed')
        cls.manifest=json.loads((OUTPUT/'manifest.json').read_text())

    def test_preserves_real_cc0_mesh_and_skin_provenance(self):
        self.assertEqual(self.manifest['sourceModel'],'innerscene_cc0_rig53')
        self.assertFalse(self.manifest['approved'])
        self.assertFalse(self.manifest['enabled'])
        self.assertEqual(self.manifest['catalogCount'],229)
        self.assertEqual(len(self.manifest['pilots']),3)
        for exercise in rig.EXERCISES:
            full_bytes,full=decode(OUTPUT/(exercise+'.glb'))
            mobile_bytes,mobile=decode(OUTPUT/(exercise+'_mobile_lod.glb'))
            self.assertEqual(full['extras']['sourceSha256'],rig.SOURCE_SHA)
            self.assertEqual(mobile['extras']['sourceSha256'],rig.SOURCE_SHA)
            self.assertFalse(full['extras']['approved'])
            self.assertFalse(mobile['extras']['enabled'])
            self.assertEqual(len(full['skins'][0]['joints']),53)
            self.assertEqual(len(mobile['skins'][0]['joints']),53)
            self.assertEqual(len(full['animations']),1)
            self.assertEqual(len(mobile['animations']),1)
            self.assertEqual(len(full['meshes'][0]['primitives']),3)
            self.assertEqual(len(mobile['meshes'][0]['primitives']),3)
            self.assertEqual(len(mobile['materials']),5 if exercise=='ex_bench_press' else 4)
            self.assertLess(len(mobile_bytes),850*1024)
            self.assertGreater(len(full_bytes),4*1024*1024)
            expected=['STK_BODY','STK_PRIMARY','STK_SECONDARY','STK_EQUIPMENT']
            if exercise=='ex_bench_press':
                expected.append('STK_CUSHION')
            self.assertEqual([m['name'] for m in full['materials']],expected)
            self.assertFalse(any('uri' in buffer for buffer in full['buffers']))
            self.assertEqual(len(full['skins'][0]['joints']),
                len(self.base.doc['skins'][0]['joints']))
            for doc in (full,mobile):
                self.assertTrue(all(s.get('interpolation')=='LINEAR'
                    for s in doc['animations'][0]['samplers']))
                self.assertEqual(doc['extras']['exerciseId'],exercise)
                self.assertEqual(doc['animations'][0]['channels'][0]['target']['path'],
                                 'rotation')
                self.assertTrue(any(n.get('name')=='STK_EXERCISE_BAR'
                                    for n in doc['nodes']))

    def test_hands_and_feet_stay_attached_at_41_keyframes(self):
        for ex in rig.EXERCISES:
            summary=next(x for x in self.manifest['pilots'] if x['id']==ex)
            self.assertLess(summary['maxGripErrorMetersAtKeyframes'],0.003)
            self.assertLess(summary['maxFootErrorMetersAtKeyframes'],0.003)
            self.assertEqual(summary['frames'],41)
            self.assertGreater(summary['trianglesByRegion']['primary'],500)
            self.assertGreater(summary['trianglesByRegion']['secondary'],100)
            for t in (0,0.4,1.6,2.0,2.8,3.6,4.0):
                loc,bar,e=rig.body_pose(self.base,ex,t)
                self.assertLess(e['gripErrorMeters'],1e-4)
                self.assertLess(e['footErrorMeters'],1e-4)
                self.assertEqual(len(bar),3)
                self.assertTrue(all(math.isfinite(x) for x in bar))
            start=rig.body_pose(self.base,ex,0)[1]
            end=rig.body_pose(self.base,ex,4)[1]
            self.assertLess(math.dist(start,end),1e-6)

    def test_rejects_wrong_source_hash(self):
        fake=bytearray(self.raw)
        fake[-1]^=1
        with self.assertRaisesRegex(ValueError,'SHA256'):
            rig.GLB(bytes(fake))

if __name__=='__main__':unittest.main()
