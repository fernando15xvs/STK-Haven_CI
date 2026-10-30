"""Offline glTF v6 continuity invariants and independent synthetic math tests."""
import json,math,os,unittest
from pathlib import Path
from retarget_cc0_glb import GLB
import build_master_surface_v6 as v6

SRC=Path(os.environ.get('STK_MASTER_CONTACTS_V5','build/cc0_master_contacts_v5'))
OUT=Path(os.environ.get('STK_MASTER_SURFACE_V6','build/cc0_master_surface_v6'))

class ContinuityMathTests(unittest.TestCase):
    def test_smoothing_reduces_artificial_spikes_without_large_shape_edits(self):
        points=((.20,0,0),(.22,0,0),(.20,.02,0),(.22,.02,0))
        graph=({1:1,2:1},{0:1,3:1},{0:1,3:1},{1:1,2:1})
        original=((.004,0,0),(0,0,0),(0,0,0),(0,0,0))
        revised,audit=v6.smooth_deltas(graph,points,original,'elbow_flexion_l')
        self.assertLess(audit['edgeGradientAfter'],audit['edgeGradientBefore'])
        self.assertLessEqual(audit['maxEditMeters'],v6.MAX_EDIT_METERS+1e-9)
        self.assertGreater(audit['editedVertices'],2)
        self.assertGreater(revised[1][0],0)
    def test_never_blends_across_body_midline(self):
        points=((.2,0,0),(-.2,0,0),(.22,0,0))
        graph=({1:1,2:1},{0:1},{0:1})
        revised,_=v6.smooth_deltas(graph,points,
            ((.004,0,0),(0,0,0),(0,0,0)),'hip_flexion_l')
        self.assertEqual(revised[1],(0.,0.,0.))
        self.assertGreater(revised[2][0],0)
    def test_invalid_stream_fails_closed(self):
        with self.assertRaises(ValueError):
            v6.smooth_deltas([{}],[(.2,0,0),(1,0,0)],[(0,0,0)],
                             'elbow_flexion_l')

class MasterV6GLBTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before=GLB((SRC/'stk_master_v5_contact_review.glb')
                       .read_bytes(),expected_sha=None)
        cls.after=GLB((OUT/'stk_master_v6_joint_surface_review.glb')
                      .read_bytes(),expected_sha=None)
        cls.report=json.loads((OUT/'joint_surface_v6_report.json').read_text())
    def test_identical_skeleton_motions_skin_and_region_topology(self):
        before=self.before.doc
        after=self.after.doc
        for part in ('nodes','skins','animations','materials'):
            self.assertEqual(before[part],after[part],part)
        self.assertEqual(before['meshes'],after['meshes'])
        self.assertEqual(before['accessors'],after['accessors'])
        self.assertEqual(before['bufferViews'],after['bufferViews'])
        self.assertEqual(after['extras']['masterSurfaceContinuityVersion'],6)
        for tag in ('approved','enabled'):
            self.assertIs(after['extras'][tag],False)
            self.assertIs(self.report[tag],False)
        self.assertFalse(self.report['anatomyCertified'])
        self.assertEqual(self.report['catalogCount'],229)
        self.assertEqual(self.report['joints'],55)
        self.assertEqual(self.report['clips'],7)
        self.assertEqual(self.report['morphTargets'],8)
        self.assertEqual(self.report['regions'],12)
        self.assertLess(self.report['bytes'],v6.BUDGET_BYTES+1)
    def test_only_corrective_geometry_changed_and_did_not_bleed_sides(self):
        mesh=self.after.doc['meshes'][0]
        attrs=mesh['primitives'][0]['attributes']
        for field in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
            i=attrs[field]
            self.assertEqual(self.before.accessor(i),self.after.accessor(i))
        points=self.after.accessor(attrs['POSITION'])
        changed=0
        for name,target in zip(v6.MORPH_NAMES,mesh['primitives'][0]['targets']):
            index=target['POSITION']
            a=self.before.accessor(index)
            b=self.after.accessor(index)
            self.assertEqual(len(a),len(points))
            maxchange=max(math.dist(x,y) for x,y in zip(a,b))
            self.assertLessEqual(maxchange,v6.MAX_EDIT_METERS+.000001)
            changed+=sum(math.dist(x,y)>1e-7 for x,y in zip(a,b))
            for p,delta in zip(points,b):
                if ((name.endswith('_l') and p[0]<=.00001) or
                    (name.endswith('_r') and p[0]>=-.00001)):
                    self.assertEqual(delta,(0.,0.,0.),name)
            self.assertLess(self.report['morphs'][name]['maxEditMeters'],
                            .001501)
        self.assertGreater(changed,100)
    def test_joint_continuity_does_not_get_worse(self):
        self.assertGreater(self.report['graphEdges'],1000)
        self.assertGreater(self.report['gradientsBefore'],0)
        self.assertLessEqual(self.report['gradientsAfter'],
                             self.report['gradientsBefore']*1.02)

if __name__=='__main__':unittest.main()
