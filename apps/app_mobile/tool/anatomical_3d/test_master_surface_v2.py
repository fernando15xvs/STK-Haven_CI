"""Master surface v2 geometry and rig invariants, not biomechanical review."""
import json,math,os,unittest
from pathlib import Path
from retarget_cc0_glb import GLB,qx
import build_master_surface_v2 as v2

BASE=Path(os.getenv('STK_MASTER_BASE',
  'build/cc0_master_character/stk_haven_master_55_unapproved.glb'))
OUT=Path(os.getenv('STK_MASTER_SURFACE','build/cc0_master_surface_v2'))

class SurfaceV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=GLB(BASE.read_bytes(),expected_sha=None)
        cls.mesh=GLB((OUT/'stk_haven_master_surface_v2_unapproved.glb').read_bytes(),
                     expected_sha=None)
        cls.report=json.loads((OUT/'master_surface_v2_report.json').read_text())

    def test_preserves_rig_skin_and_all_source_triangles(self):
        src=self.base.doc
        dst=self.mesh.doc
        self.assertEqual(src['skins'],dst['skins'])
        self.assertEqual(len(dst['skins'][0]['joints']),55)
        self.assertEqual(len(dst.get('animations',[])),0)
        self.assertEqual(len(dst['meshes'][0]['primitives']),12)
        self.assertEqual(self.report['sourceSha256'],v2.SOURCE_SHA)
        self.assertFalse(self.report['approved'])
        self.assertFalse(self.report['enabled'])
        self.assertEqual(self.report['catalogCount'],229)
        for old,new in zip(src['meshes'][0]['primitives'],dst['meshes'][0]['primitives']):
            self.assertEqual(old['indices'],new['indices'])
            self.assertEqual(old['extras'],new['extras'])
            for field in ('JOINTS_0','WEIGHTS_0'):
                self.assertEqual(old['attributes'][field],new['attributes'][field])

    def test_muscle_relief_keeps_face_orientation(self):
        originals=self.base.doc['meshes'][0]['primitives']
        src=self.base.accessor(originals[0]['attributes']['POSITION'])
        dst=self.mesh.accessor(originals[0]['attributes']['POSITION'])
        d=[math.dist(a,b) for a,b in zip(src,dst)]
        self.assertGreater(sum(val>.002 for val in d),4500)
        self.assertLess(sum(val>.002 for val in d),18000)
        self.assertLessEqual(max(d),.011)
        for primitive in originals:
            triangles=[int(v[0]) for v in self.base.accessor(primitive['indices'])]
            for k in range(0,len(triangles),3):
                a,b,c=triangles[k:k+3]
                original=v2.cross(v2.sub(src[b],src[a]),v2.sub(src[c],src[a]))
                changed=v2.cross(v2.sub(dst[b],dst[a]),v2.sub(dst[c],dst[a]))
                self.assertGreater(sum(x*y for x,y in zip(original,changed)),0)

    def test_eight_joint_correctives_are_unilateral_and_off_by_default(self):
        m=self.mesh.doc['meshes'][0]
        names=m['extras']['targetNames']
        self.assertEqual(len(names),8)
        self.assertEqual(set(names),set(self.report['morphTargets']))
        self.assertEqual(m['weights'],[0.]*8)
        points=self.mesh.accessor(m['primitives'][0]['attributes']['POSITION'])
        for p in m['primitives']:self.assertEqual(len(p['targets']),8)
        for target,name in zip(m['primitives'][0]['targets'],names):
            deltas=self.mesh.accessor(target['POSITION'])
            observed=[(points[i][0],v2.length3(d))
                      for i,d in enumerate(deltas) if v2.length3(d)>.0001]
            self.assertGreater(len(observed),25,name)
            wrong=[v for x,v in observed
                   if (name.endswith('_l') and x<0) or
                      (name.endswith('_r') and x>0)]
            self.assertEqual(wrong,[],name)
            self.assertLess(max(v for _,v in observed),.0051)
            self.assertFalse(self.report['morphTargets'][name]['driverConnected'])

    def test_four_kinematic_families_leave_opposite_side_unchanged(self):
        rig=self.mesh
        for parent,end in [('upperarm_l','hand_l'),('lowerarm_l','hand_l'),
                           ('thigh_l','foot_l'),('calf_l','foot_l')]:
            pivot=rig.by_name[parent]
            local={pivot:(tuple(rig.nodes[pivot].get('translation',(0,0,0))),qx(.38))}
            world,_=rig.world(local)
            self.assertGreater(math.dist(world[rig.by_name[end]],
                rig.restpos[rig.by_name[end]]),.015)
            other=end[:-1]+'r'
            self.assertLess(math.dist(world[rig.by_name[other]],
                rig.restpos[rig.by_name[other]]),.0001)
        self.assertEqual(rig.doc['animations'],[])

if __name__=='__main__':
    unittest.main()
