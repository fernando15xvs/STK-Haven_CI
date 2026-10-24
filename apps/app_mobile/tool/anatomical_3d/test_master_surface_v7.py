"""v7 CC0 procedural surface quality gates, never clinical QA."""
import json
import math
import os
import unittest
from pathlib import Path

from retarget_cc0_glb import GLB
import build_master_surface_v7 as v7

BASE=Path(os.getenv("STK_MASTER_SURFACE_V6","build/cc0_master_surface_v6"))
OUT=Path(os.getenv("STK_MASTER_SURFACE_V7","build/cc0_master_surface_v7"))

class ProceduralDetailMathTests(unittest.TestCase):
    def test_symmetrical_bounded_bilateral_lobes(self):
        # Repeat the symmetric synthetic triangles to satisfy the same
        # >100 changed-vertex safety gate required for the real sculpt.
        # Do NOT weaken the production quality gate just for this test.
        unit=(
            (.20,.7,.10),(.25,.7,.10),(.20,.8,.10),
            (-.20,.7,.10),(-.25,.7,.10),(-.20,.8,.10),
        )
        adjacency=(
            {1:1.,2:1.},{0:1.,2:1.},{0:1.,1:1.},
            {4:1.,5:1.},{3:1.,5:1.},{3:1.,4:1.},
        )
        points=tuple((x,y+row*.002,z)
                     for row in range(20) for x,y,z in unit)
        normals=[(0,0,1)]*len(points)
        graph=[{j+6*row:weight for j,weight in edges.items()}
               for row in range(20) for edges in adjacency]
        votes={name:[1.]*len(points) for name in v7.REGION_RELIEF_METERS}
        moved,metrics=v7.detail(points,normals,votes,graph)
        self.assertEqual(metrics["editedVertices"],len(points))
        for before,after in zip(points,moved):
            self.assertGreater(after[2]-before[2],.0001)
            self.assertLessEqual(math.dist(before,after),.00150001)
        for row in range(20):
            for left,right in ((0,3),(1,4),(2,5)):
                i,j=6*row+left,6*row+right
                self.assertAlmostEqual(moved[i][2],moved[j][2],delta=1e-7)
        self.assertTrue(metrics["bilateralMirroredProfiles"])

    def test_folded_triangle_and_bad_region_inputs_fail_closed(self):
        faces={"test":[0,1,2]}
        neutral=[(0,0,0),(1,0,0),(0,1,0)]
        v7.face_orientation(neutral,neutral,faces)
        with self.assertRaises(ValueError):
            v7.face_orientation(neutral,
                [(0,0,0),(0,1,0),(1,0,0)],faces)
        self.assertEqual(v7.smoothstep(-1),0)
        self.assertEqual(v7.smoothstep(2),1)

class RealMasterSurfaceV7Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before=GLB((BASE/"stk_master_v6_joint_surface_review.glb")
                       .read_bytes(),expected_sha=None)
        cls.after=GLB((OUT/"stk_master_v7_surface_preview.glb")
                      .read_bytes(),expected_sha=None)
        cls.report=json.loads((OUT/"master_surface_v7_report.json").read_text())

    def test_preserves_all_skeleton_clips_and_stable_exercise_catalog(self):
        a,b=self.before.doc,self.after.doc
        for name in ("skins","nodes","meshes","animations","materials",
                     "accessors","bufferViews"):
            self.assertEqual(a[name],b[name],name)
        for name,value in (("masterSculptDetailVersion",7),
                           ("approved",False),("enabled",False)):
            self.assertEqual(b["extras"][name],value)
        self.assertFalse(self.report["productionReady"])
        self.assertFalse(self.report["anatomyCertified"])
        self.assertEqual(self.report["catalogCount"],229)
        self.assertEqual(self.report["clips"],7)
        self.assertEqual(self.report["joints"],55)
        self.assertEqual(self.report["morphTargets"],8)
        self.assertEqual(self.report["regionPrimitives"],12)
        self.assertEqual(len(self.report["regionsEnhanced"]),6)
        self.assertLessEqual(self.report["bytes"],850*1024)
        self.assertGreater(self.report["triangleCount"],4000)

    def test_no_skin_weight_indices_or_morph_deltas_changed(self):
        mesh=self.before.doc["meshes"][0]
        attrs=mesh["primitives"][0]["attributes"]
        for name in ("WEIGHTS_0","JOINTS_0"):
            index=attrs[name]
            self.assertEqual(self.before.accessor(index),
                             self.after.accessor(index),name)
        for target in mesh["primitives"][0]["targets"]:
            i=target["POSITION"]
            self.assertEqual(self.before.accessor(i),
                             self.after.accessor(i))

    def test_enhances_neutral_silhouette_without_mesh_foldover(self):
        mesh=self.before.doc["meshes"][0]
        attrs=mesh["primitives"][0]["attributes"]
        original=self.before.accessor(attrs["POSITION"])
        refined=self.after.accessor(attrs["POSITION"])
        norms=self.after.accessor(attrs["NORMAL"])
        changes=[math.dist(a,b) for a,b in zip(original,refined)]
        self.assertGreater(sum(v>.00002 for v in changes),100)
        self.assertLessEqual(max(changes),v7.MAX_VERTEX_EDIT_METERS+.000001)
        self.assertTrue(all(math.isfinite(x) for p in refined for x in p))
        self.assertTrue(all(abs(v7.norm(n)-1)<.002 for n in norms))
        _,faces=v7.region_votes(self.before,len(original))
        self.assertEqual(v7.face_orientation(original,refined,faces),
                         self.report["triangleCount"])
        self.assertLessEqual(self.report["metrics"]["maxEditMeters"],.0015)
        self.assertGreater(self.report["metrics"]["editedVertices"],100)

if __name__=="__main__":
    unittest.main()
