"""Strict standalone GLB staging tests (no third-party dependencies)."""
import importlib.util
import json
import math
import struct
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('build_anatomical_glb', HERE/'build_anatomical_glb.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class GlbAnatomicalStageTest(unittest.TestCase):
    def test_rig_19_named_joints_and_stable_exercise_ids(self):
        self.assertEqual(len(builder.BONES), 19)
        self.assertEqual(tuple(builder.IDS), ('ex_bench_press','ex_barbell_row','ex_squat'))
        self.assertEqual(len(set(x[0] for x in builder.BONES)), 19)
        for name,parent,_ in builder.BONES:
            self.assertTrue(parent is None or parent in builder.INDEX)

    def test_smooth_cycle_closes_and_has_distinct_motion(self):
        self.assertEqual(builder.phase(0),0)
        self.assertEqual(builder.phase(1),0)
        self.assertGreater(builder.phase(.53),.999)
        for exercise in builder.IDS:
            self.assertEqual(builder.root_translation(exercise,0),
                builder.root_translation(exercise,4))
            self.assertEqual(builder.bar_translation(exercise,0),
                builder.bar_translation(exercise,4))
            self.assertNotEqual(builder.bar_translation(exercise,0),
                builder.bar_translation(exercise,2))
            for bone,_,_ in builder.BONES:
                self.assertEqual(builder.quat_sequence(bone,0,exercise),
                    builder.quat_sequence(bone,4,exercise))
                for t in [0,1,2,3,4]:
                    q=builder.quat_sequence(bone,t,exercise)
                    self.assertAlmostEqual(math.sqrt(sum(v*v for v in q)),1,places=6)

    def test_exports_structural_gltf2_skin_and_animation(self):
        for exercise in builder.IDS:
            raw,info=builder.make_glb(exercise)
            self.assertGreater(len(raw),100000)
            self.assertLess(len(raw),850000)
            self.assertEqual(struct.unpack_from('<I',raw,8)[0],len(raw))
            doc=builder.extract_glb(raw)
            self.assertEqual(doc['asset']['version'],'2.0')
            self.assertEqual(doc['extras']['exerciseId'],exercise)
            self.assertFalse(doc['extras']['approved'])
            self.assertFalse(doc['extras']['enabled'])
            self.assertEqual(len(doc['skins']),1)
            self.assertEqual(len(doc['skins'][0]['joints']),19)
            self.assertEqual(len(doc['animations']),1)
            self.assertGreater(len(doc['animations'][0]['channels']),10)
            self.assertGreater(len(doc['meshes']),1)
            self.assertEqual(doc['scenes'][0]['nodes'][0],0)
            self.assertEqual(doc['skins'][0]['inverseBindMatrices']>=0,True)
            self.assertTrue(all('uri' not in buf for buf in doc['buffers']))
            self.assertTrue(all('uri' not in image for image in doc.get('images',[])))
            self.assertEqual(len(doc['materials']),9)
            roles={m['extras']['stkMuscleRole'] for m in doc['materials']}
            self.assertIn('primary',roles)
            self.assertIn('secondary',roles)
            names={n['name'] for n in doc['nodes']}
            self.assertIn('SKEL_pelvis',names)
            self.assertIn('STK_SKINNED_BODY',names)
            self.assertIn('BARBELL_ANIMATED',names)
            meshes=[p for mesh in doc['meshes'] for p in mesh['primitives']]
            self.assertTrue(any('WEIGHTS_0' in m['attributes'] for m in meshes))
            self.assertTrue(any('JOINTS_0' in m['attributes'] for m in meshes))
            self.assertEqual(info['bones'],19)
            self.assertGreater(info['triangles'],10000)
            self.assertLess(info['vertices'],10000)
            self.assertEqual(info['approved'],False)
            self.assertEqual(info['enabled'],False)
            views=doc['bufferViews'];buffer=doc['buffers'][0]
            self.assertTrue(all(v['byteOffset']%4==0 for v in views))
            self.assertTrue(all(v['byteOffset']+v['byteLength']<=buffer['byteLength'] for v in views))
            # Every accessor references a valid view and joint arrays are normalized.
            for accessor in doc['accessors']:
                self.assertLess(accessor['bufferView'],len(views))
                self.assertGreater(accessor['count'],0)
            for part in meshes:
                self.assertLess(part['material'],len(doc['materials']))
                self.assertLess(part['indices'],len(doc['accessors']))
                for id0 in part['attributes'].values():
                    self.assertLess(id0,len(doc['accessors']))
                attrs=part['attributes']
                if 'WEIGHTS_0' in attrs:
                    weightacc=doc['accessors'][attrs['WEIGHTS_0']]
                    wv=views[weightacc['bufferView']]
                    # GLB BIN chunk begins after padded JSON chunk.
                    jsonlen=struct.unpack_from('<I',raw,12)[0]
                    binaryoffset=20+jsonlen+8
                    for i in range(weightacc['count']):
                        weights=struct.unpack_from('<4f',raw,binaryoffset+wv['byteOffset']+i*16)
                        self.assertTrue(all(0 <= w <= 1 for w in weights))
                        self.assertAlmostEqual(sum(weights),1.,places=5)

    def test_reproducible_isolated_stage_not_published(self):
        with tempfile.TemporaryDirectory() as a,tempfile.TemporaryDirectory() as b:
            first=builder.build(a);second=builder.build(b)
            self.assertFalse(first['approved'])
            self.assertFalse(first['enabled'])
            self.assertEqual(first,second)
            for file in Path(a).iterdir():
                self.assertEqual(file.read_bytes(),(Path(b)/file.name).read_bytes())
            self.assertEqual(len(first['items']),3)
            self.assertEqual(sum(x['bytes'] for x in first['items'])<3*850000,True)


if __name__=='__main__':
    unittest.main()
