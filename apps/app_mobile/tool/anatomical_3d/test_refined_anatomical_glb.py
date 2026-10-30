"""Strict geometry/weight gates for internal STK Haven v3.2 GLB junctions."""
import json
import math
import tempfile
import unittest
from pathlib import Path

import build_anatomical_glb as base
import build_refined_anatomical_glb as refined

EXPECTED_REGIONS = {
    'cervico_thoracic_junction',
    *('scapular_humeral_junction_' + side for side in ('L', 'R')),
    *('superior_trapezius_' + side for side in ('L', 'R')),
    *('iliac_femoral_junction_' + side for side in ('L', 'R')),
    *('femoral_tibial_junction_' + side for side in ('L', 'R')),
    *('patellar_tendon_' + side for side in ('L', 'R')),
}


class RefinedJunctionsTest(unittest.TestCase):
    def test_all_regions_are_actual_weighted_triangle_meshes(self):
        for exercise in base.IDS:
            old=base.humanoid(exercise)
            geometry=refined.refined_humanoid(exercise)
            extra=geometry.primitives[len(old.primitives):]
            names={item[0] for item in extra}
            self.assertEqual(names,EXPECTED_REGIONS)
            self.assertEqual(len(extra),11)
            self.assertLess(geometry.total_vertices,9500)
            self.assertLess(geometry.triangles,16500)
            self.assertGreater(geometry.triangles,old.triangles)
            for name,positions,normals,triangles,role,blends in extra:
                with self.subTest(exercise=exercise,name=name):
                    self.assertGreater(len(positions),35)
                    self.assertEqual(len(positions),len(normals))
                    self.assertEqual(len(positions),len(blends))
                    self.assertTrue(role in ('body','muscle'))
                    self.assertTrue(all(0<=idx<len(positions)
                                        for tri in triangles for idx in tri))
                    for xyz,normal,(joint_ids,weights) in zip(positions,normals,blends):
                        self.assertTrue(all(math.isfinite(v) for v in xyz))
                        self.assertTrue(all(math.isfinite(v) for v in normal))
                        self.assertAlmostEqual(sum(weights),1.,places=6)
                        self.assertTrue(all(0<=w<=1 for w in weights))
                        self.assertTrue(all(0<=j<len(base.BONES) for j in joint_ids))
                    self.assertTrue(any(sum(w>.05 for w in weights)>1
                         for _,weights in blends), 'Every new junction should deform across a seam')

    def test_weights_change_gradually_across_each_sweep(self):
        geo=refined.refined_humanoid(base.IDS[0]); regions=geo.primitives[-11:]
        # Each adjacent ring has blended weight changes, not abruptly switched bones.
        for name,positions,_,_,_,blends in regions:
            n = 20 if name.startswith(('scapular','femoral')) else 18 if name.startswith('iliac') else 12 if name.startswith('patellar') else 16
            # Cervical ring uses 16, and trapezius ring uses 16.
            with self.subTest(name=name):
                self.assertEqual((len(positions)-2)%n,0)
                counts=(len(positions)-2)//n
                for row in range(counts-1):
                    ja,wa=blends[row*n]
                    jb,wb=blends[(row+1)*n]
                    left={i:w for i,w in zip(ja,wa) if w>0}
                    right={i:w for i,w in zip(jb,wb) if w>0}
                    distance=max(abs(left.get(j,0)-right.get(j,0))
                                 for j in left.keys()|right.keys())
                    self.assertLess(distance,.62,name)


    def test_glb_v32_is_deterministic_unpublished_and_below_budget(self):
        original=base.humanoid
        with tempfile.TemporaryDirectory() as aa,tempfile.TemporaryDirectory() as bb:
            a=refined.build(aa);b=refined.build(bb)
            self.assertIs(base.humanoid,original)
            self.assertEqual(a,b)
            self.assertFalse(a['approved'])
            self.assertFalse(a['enabled'])
            self.assertEqual(a['catalogCount'],229)
            self.assertEqual(a['junctionMeshesPerPilot'],11)
            self.assertEqual([i['id'] for i in a['items']],list(base.IDS))
            for entry in a['items']:
                self.assertLess(entry['bytes'],850*1024)
                self.assertLess(entry['vertices'],9500)
                self.assertEqual(entry['bones'],19)
                f=Path(aa,entry['id']+'.glb')
                self.assertEqual(f.read_bytes(),Path(bb,f.name).read_bytes())
                parsed=base.extract_glb(f.read_bytes())
                self.assertFalse(parsed['extras']['approved'])
                self.assertFalse(parsed['extras']['enabled'])
                region_names={primitive['extras']['anatomicalRegion']
                    for primitive in parsed['meshes'][0]['primitives']}
                self.assertTrue(EXPECTED_REGIONS.issubset(region_names))
            self.assertEqual(Path(aa,'manifest.json').read_bytes(),
                             Path(bb,'manifest.json').read_bytes())


if __name__=='__main__': unittest.main()
