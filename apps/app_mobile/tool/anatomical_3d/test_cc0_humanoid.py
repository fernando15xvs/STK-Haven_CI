"""License and GLB acceptance gates; candidate is not yet distributed."""
import importlib.util
import json
import struct
import unittest
from pathlib import Path
import stage_cc0_humanoid as stage

def fake_glb(joints=53):
    rig = {"asset":{"version":"2.0"},
           "nodes":[{"name":f"joint_{n}"} for n in range(joints)],
           "meshes":[{"name":"body","primitives":[]}],
           "skins":[{"joints":list(range(joints))}],
           "buffers":[{"byteLength":4}]}
    payload=json.dumps(rig,separators=(",",":")).encode()
    payload+=b" " * ((-len(payload))%4)
    raw=struct.pack("<4sII",b"glTF",2,12+8+len(payload)+8+4)
    return raw+struct.pack("<I4s",len(payload),b"JSON")+payload+struct.pack(
        "<I4s",4,b"BIN\x00")+b"\0\0\0\0"

class LicenseTest(unittest.TestCase):
    def test_selected_cc0_license_evidence(self):
        registry=json.loads(stage.REGISTRY.read_text(encoding="utf8"))
        self.assertEqual(registry["chosen_source"],stage.SELECTED)
        chosen=stage.selected()
        self.assertEqual(chosen["sha256"],
            "7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749")
        self.assertEqual(chosen["license"],"CC0-1.0")
        self.assertTrue(chosen["commercial_allowed"])
        self.assertTrue(chosen["redistribution_allowed"])
        self.assertFalse(chosen["attribution_required"])
        self.assertTrue(chosen["download_url"].startswith("https://www.innerscene.com/"))
        sharealike=next(x for x in registry["candidates"] if "z_anatomy" in x["id"])
        self.assertEqual(sharealike["license"],"CC-BY-SA-4.0")
        self.assertNotEqual(chosen["id"],sharealike["id"])
        self.assertFalse(chosen["staged"])
    def test_glb_requires_full_rig_not_19_bone_old_prototype(self):
        self.assertEqual(stage.inspect_glb(fake_glb())["jointCount"],53)
        with self.assertRaises(stage.StageError):
            stage.inspect_glb(fake_glb(19))
        with self.assertRaises(stage.StageError):
            stage.inspect_glb(b"wrong")
    def test_network_download_is_never_used_during_unit_tests(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            # Fake GLB must not match the pinned real 53-bone model SHA.
            fixture_license=dict(stage.selected())
            fixture_license["sha256"]=None
            record=stage.stage(fake_glb(),Path(tmp),fixture_license)
            self.assertFalse(record["approved"])
            self.assertFalse(record["enabled"])
            self.assertFalse(record["movementRetargeted"])
            self.assertFalse(record["anatomicalMuscleMasksReady"])
            self.assertTrue((Path(tmp)/"source_provenance.json").exists())
            self.assertTrue((Path(tmp)/"human-base-rigged-cc0.glb").exists())

if __name__=="__main__":
    unittest.main()
