"""Exercise-independent 55-joint master motion clips and shape-key driver gates."""
import json, math, os, unittest
from pathlib import Path
from retarget_cc0_glb import GLB
import build_master_motion_v3 as m

ROOT=Path(os.getenv("STK_MASTER_MOTION_V3","build/cc0_master_motion_v3"))
BASE=Path(os.getenv("STK_MASTER_SURFACE","build/cc0_master_surface_v2"))
RAW=ROOT/"stk_master_55_motion_lab_v3_unapproved.glb"

class MasterMotionV3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=GLB((BASE/"stk_haven_master_surface_v2_unapproved.glb").read_bytes(),expected_sha=None)
        cls.glb=GLB(RAW.read_bytes(),expected_sha=None)
        cls.report=json.loads((ROOT/"master_motion_v3_report.json").read_text())
    def test_preserves_skinned_master_and_neutral_sculpt(self):
        self.assertEqual(self.glb.doc["skins"],self.source.doc["skins"])
        self.assertEqual(self.glb.doc["meshes"],self.source.doc["meshes"])
        self.assertEqual(len(self.glb.doc["skins"][0]["joints"]),55)
        self.assertEqual(len(self.glb.doc["animations"]),7)
        self.assertEqual(self.glb.doc["meshes"][0]["weights"],[0.]*8)
        self.assertEqual(self.report["catalogCount"],229)
        self.assertFalse(self.report["approved"])
        self.assertFalse(self.report["enabled"])
        self.assertFalse(self.glb.doc["extras"]["approved"])
        self.assertFalse(self.glb.doc["extras"]["enabled"])
        self.assertEqual(self.report["sourceMasterSurfaceSha256"],
                         self.glb.doc["extras"]["sourceMasterSurfaceSha256"])
    def test_seven_clips_drive_real_gltf_morphs_and_joint_quaternions(self):
        for clip in self.glb.doc["animations"]:
            pattern=m.PATTERNS[clip["extras"]["pattern"]]
            channels=clip["channels"];samplers=clip["samplers"]
            self.assertEqual(len(channels),len(pattern["joints"])+1)
            weights=[c for c in channels if c["target"]["path"]=="weights"]
            self.assertEqual(len(weights),1)
            scalar=self.glb.accessor(samplers[weights[0]["sampler"]]["output"])
            self.assertEqual(len(scalar),m.FRAMES*8)
            series=[v[0] for v in scalar]
            self.assertTrue(all(math.isfinite(v) and 0<=v<=1. for v in series))
            self.assertGreater(max(series),.28)
            self.assertTrue(all(v==0 for v in series[:8]+series[-8:]))
            for i in range(m.FRAMES):
                for j,name in enumerate(m.MORPH_KEYS):
                    self.assertAlmostEqual(series[i*8+j],
                        m.phase(i/10.)*pattern["drivers"].get(name,0),delta=1e-5)
            for channel in channels:
                sample=samplers[channel["sampler"]]
                times=[value[0] for value in self.glb.accessor(sample["input"])]
                self.assertEqual(len(times),41)
                self.assertEqual(times[0],0)
                self.assertEqual(times[-1],4)
                self.assertEqual(sample["interpolation"],"LINEAR")
                if channel["target"]["path"]=="rotation":
                    rotations=self.glb.accessor(sample["output"])
                    self.assertEqual(len(rotations),41)
                    self.assertTrue(all(abs(sum(x*x for x in q)-1)<.0001 for q in rotations))
                    self.assertTrue(all(sum(a*b for a,b in zip(rotations[i],rotations[i+1]))>0
                                        for i in range(40)))
                    self.assertTrue(all(abs(a-b)<1e-6
                                    for a,b in zip(rotations[0],rotations[-1])))
    def test_unilateral_controls_do_not_drive_other_arm(self):
        for side in ("left","right"):
            label="unilateral_reach_"+side
            clip=next(c for c in self.glb.doc["animations"]
                     if c["extras"]["pattern"]==label)
            other="r" if side=="left" else "l"
            rotations={self.glb.nodes[c["target"]["node"]]["name"]
                       for c in clip["channels"] if c["target"]["path"]=="rotation"}
            self.assertTrue(all(not name.endswith("_"+other) for name in rotations))
            weights_channel=next(c for c in clip["channels"]
                                  if c["target"]["path"]=="weights")
            scalar=self.glb.accessor(clip["samplers"][weights_channel["sampler"]]["output"])
            for k,region in enumerate(m.MORPH_KEYS):
                if region.endswith("_"+other):
                    self.assertTrue(all(scalar[i*8+k][0]==0 for i in range(41)))
    def test_pose_displaces_limb_but_does_not_claim_foot_ik(self):
        rig=self.glb
        for clip in rig.doc["animations"]:
            local={}
            for channel in clip["channels"]:
                if channel["target"]["path"]!="rotation":continue
                index=channel["target"]["node"]
                rotation=rig.accessor(clip["samplers"][channel["sampler"]]["output"])[20]
                local[index]=(tuple(rig.nodes[index].get("translation",(0,0,0))),rotation)
            pos,_=rig.world(local)
            displacement=max(math.dist(pos[rig.by_name[bone]],rig.restpos[rig.by_name[bone]])
                         for bone in ("hand_l","hand_r","foot_l","foot_r"))
            self.assertGreater(displacement,.03,clip["name"])
            self.assertFalse(clip["extras"]["hasFootIK"])
            self.assertFalse(clip["extras"]["biomechanicsReviewed"])
        self.assertTrue(all(not x["footContactValidated"]
                            for x in self.report["patterns"].values()))
if __name__=="__main__":unittest.main()
