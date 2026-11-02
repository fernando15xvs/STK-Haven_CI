"""Independent master rig tests: no destructive retarget or mislabelled approval."""
import json,math,os,struct,unittest
from pathlib import Path
import retarget_cc0_glb as base
import build_master_character as master

SOURCE=Path(os.getenv("STK_CC0_MODEL",
  "build/cc0_model_stage/human-base-rigged-cc0.glb"))
OUT=Path(os.getenv("STK_MASTER_OUT","build/cc0_master_character"))

class MasterCharacterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=base.GLB(SOURCE.read_bytes())
        cls.master=base.GLB((OUT/"stk_haven_master_55_unapproved.glb").read_bytes(),
                            expected_sha=None)
        cls.profile=json.loads((OUT/"master_character_profile.json").read_text())

    def test_preserves_original_body_topology_and_cc0_provenance(self):
        original=self.source.doc["meshes"][0]["primitives"][0]
        output=self.master.doc["meshes"][0]
        self.assertEqual(self.profile["sourceSha256"],base.SOURCE_SHA)
        self.assertFalse(self.profile["approved"])
        self.assertFalse(self.profile["enabled"])
        self.assertEqual(self.profile["catalogCount"],229)
        self.assertEqual(len(self.master.doc["animations"]),0)
        self.assertEqual(len(self.master.doc["meshes"]),1)
        self.assertEqual(len(self.master.doc["skins"][0]["joints"]),55)
        self.assertEqual(len(output["primitives"]),12)
        src_v=self.source.accessor(original["attributes"]["POSITION"])
        src_j=self.source.accessor(original["attributes"]["JOINTS_0"])
        src_w=self.source.accessor(original["attributes"]["WEIGHTS_0"])
        self.assertEqual(src_v,self.master.accessor(
          output["primitives"][0]["attributes"]["POSITION"]))
        self.assertEqual(src_j,self.master.accessor(
          output["primitives"][0]["attributes"]["JOINTS_0"]))
        self.assertEqual(src_w,self.master.accessor(
          output["primitives"][0]["attributes"]["WEIGHTS_0"]))
        src_ibm=self.source.accessor(self.source.doc["skins"][0]["inverseBindMatrices"])
        master_ibm=self.master.accessor(self.master.doc["skins"][0]["inverseBindMatrices"])
        self.assertEqual(src_ibm,master_ibm[:53])
        old_indices=len(self.source.accessor(original["indices"]))
        new_indices=sum(len(self.master.accessor(prim["indices"]))
               for prim in output["primitives"])
        self.assertEqual(old_indices,107024*3)
        self.assertEqual(new_indices,old_indices)
        self.assertTrue(all(p["extras"]["reviewed"] is False
          for p in output["primitives"]))

    def test_neutral_rest_pose_exact_and_scapula_independent(self):
        for i in range(len(self.source.nodes)):
            a=self.source.restpos[i]
            b=self.master.restpos[i]
            self.assertLess(math.dist(a,b),.0001,(i,self.source.nodes[i].get("name")))
        for side in ("l","r"):
            scap=self.master.by_name["stk_scapula_control_"+side]
            clav=self.master.by_name["clavicle_"+side]
            upper=self.master.by_name["upperarm_"+side]
            self.assertEqual(self.master.parents[clav],scap)
            profile_control=self.profile["rigControls"]["scapula"][side]
            joint_index=profile_control["jointIndex"]
            self.assertEqual(self.master.doc["skins"][0]["joints"][joint_index],scap)
            self.assertEqual(joint_index,53 if side=="l" else 54)
            rest=self.master.restpos[upper]
            loc={scap:(tuple(self.master.nodes[scap]["translation"]),base.qx(.18))}
            displaced=self.master.world(loc)[0][upper]
            self.assertGreater(math.dist(rest,displaced),.012)
            self.assertLess(math.dist(rest,displaced),.06)
            other="r" if side=="l" else "l"
            unaffected=self.master.world(loc)[0][self.master.by_name["upperarm_"+other]]
            self.assertLess(math.dist(unaffected,
                self.master.restpos[self.master.by_name["upperarm_"+other]]),.0001)

    def test_regions_are_exercise_independent_and_bilateral(self):
        regions=self.profile["muscleRegionGroups"]
        self.assertEqual(len(regions)-1,11)
        self.assertGreater(regions["body"]["triangles"],95000)
        self.assertEqual(sum(x["triangles"] for x in regions.values()),107024)
        for label,counts in regions.items():
            if label=="body":continue
            left,right=counts["left"],counts["right"]
            self.assertGreater(min(left,right),18)
            self.assertLess(abs(left-right)/(left+right),.11,label)
            self.assertFalse(counts["anatomistApproved"])
        self.assertEqual(self.profile["exerciseBindings"],{})
        self.assertFalse(self.profile["rigControls"]["forearmTwist"]["implemented"])
        self.assertFalse(self.profile["rigControls"]["correctiveBlendshapes"]["implemented"])
        self.assertEqual(self.master.doc["extras"]["approved"],False)

if __name__=="__main__":unittest.main()
