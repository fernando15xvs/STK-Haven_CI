"""Pilot technique constraints with numerical samples; NOT biomechanical approval."""
import json, math, os, struct, unittest
from pathlib import Path
import retarget_cc0_glb as rig

SOURCE=Path(os.environ.get('STK_CC0_MODEL','build/cc0_model_stage/human-base-rigged-cc0.glb'))
OUT=Path(os.environ.get('STK_CC0_RETARGET','build/cc0_53bone_retarget'))

class TechniquePilotTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.glb=rig.GLB(SOURCE.read_bytes())

    def test_bench_is_supine_and_has_immobile_cushion(self):
        glb=self.glb
        for t in (i*.05 for i in range(81)):
            local,bar,errors=rig.body_pose(glb,'ex_bench_press',t)
            pose,_=glb.world(local)
            hip=pose[glb.by_name['pelvis']]
            head=pose[glb.by_name['head']]
            self.assertLess(abs(head[1]-hip[1]),.13)
            self.assertLess(head[2]-hip[2],-.55)
            self.assertGreater(hip[1],.68)
            self.assertLess(errors['gripErrorMeters'],.003)
            self.assertLess(errors['footErrorMeters'],.003)
        for name in ('ex_bench_press.glb','ex_bench_press_mobile_lod.glb'):
            raw=(OUT/name).read_bytes()
            count=struct.unpack_from('<I',raw,12)[0]
            doc=json.loads(raw[20:20+count])
            self.assertIn('STK_BENCH_STATIONARY',[n.get('name') for n in doc['nodes']])
            self.assertIn('STK_BENCH_STATIC',[m['name'] for m in doc['meshes']])
            self.assertEqual(len(doc['meshes']),3)
            self.assertEqual(len(doc['materials']),5)
            names=[n.get('name') for n in doc['nodes']]
            bench=doc['nodes'][names.index('STK_BENCH_STATIONARY')]
            self.assertNotIn('skin',bench)
            clip=doc['animations'][0]
            self.assertFalse(any(c['target']['node']==names.index(
                'STK_BENCH_STATIONARY') for c in clip['channels']))

    def test_row_has_hip_hinge_and_weight_below_shoulders(self):
        glb=self.glb
        for t in (i*.05 for i in range(81)):
            local,bar,errors=rig.body_pose(glb,'ex_barbell_row',t)
            pose,_=glb.world(local)
            hip=pose[glb.by_name['pelvis']]
            head=pose[glb.by_name['head']]
            shoulder=pose[glb.by_name['upperarm_l']]
            self.assertGreater(head[2]-hip[2],.50)
            self.assertLess(head[1]-hip[1],.30)
            self.assertLess(bar[1],shoulder[1]-.12)
            self.assertLess(errors['gripErrorMeters'],.003)
            self.assertLess(errors['footErrorMeters'],.003)

    def test_squat_preserves_forward_knee_and_contact(self):
        glb=self.glb
        for t in (i*.05 for i in range(81)):
            local,bar,errors=rig.body_pose(glb,'ex_squat',t)
            pose,_=glb.world(local)
            self.assertLess(errors['gripErrorMeters'],.003)
            self.assertLess(errors['footErrorMeters'],.003)
            if 1.8<=t<=2.2:
                self.assertGreater(pose[glb.by_name['calf_l']][2]-
                                   pose[glb.by_name['thigh_l']][2],.30)
        for ex in rig.EXERCISES:
            a=rig.body_pose(glb,ex,0)[1]
            b=rig.body_pose(glb,ex,4)[1]
            self.assertLess(math.dist(a,b),1e-7)

if __name__=='__main__':
    unittest.main()
