"""Quick, dependency-free checks of offline SVG review tooling."""
import json
import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

from exercise_lottie_review import frame_value, geometry_report, storyboard


class LottieReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[1]
        cls.asset = json.loads(
            (cls.root / "assets/exercise_media/lottie/ex_bench_press.json")
            .read_text(encoding="utf-8")
        )

    def test_animated_transform_returns_to_first_frame(self):
        moving = next(
            layer for layer in self.asset["layers"]
            if layer["ks"]["p"]["a"] == 1
        )
        position = moving["ks"]["p"]
        first = frame_value(position, 0)
        middle = frame_value(position, 30)
        return_pose = frame_value(position, 60)
        self.assertNotEqual(first, middle)
        self.assertEqual(first, return_pose)
        halfway = frame_value(position, 15)
        self.assertNotEqual(halfway, first)
        self.assertNotEqual(halfway, middle)

    def test_geometry_inspector_reads_both_types_of_motion(self):
        moving, layers, warnings = geometry_report(self.asset)
        self.assertGreater(layers, 10)
        self.assertIsInstance(moving, int)
        self.assertFalse(any("nonfinite" in w or "invalid path" in w
                             for w in warnings))

    def test_svg_review_sheet_has_five_frames_and_warning(self):
        with tempfile.TemporaryDirectory() as tmp:
            svg = Path(tmp) / "bench.svg"
            storyboard(self.asset, {"id": "ex_bench_press",
                                    "name": "Press de banca"}, svg)
            content = svg.read_text(encoding="utf-8")
            ET.parse(svg)
            self.assertEqual(content.count("Fotograma "), 5)
            self.assertIn("SIN APROBAR", content)
            self.assertIn("ex_bench_press", content)

    def test_revised_high_risk_drafts_have_distinct_movement_landmarks(self):
        requirements = {
            "exv2_kettlebell_swing": {
                "Campana kettlebell visible",
                "Torso neutro bisagra a erecto",
            },
            "exv2_russian_twist": {
                "Manos juntas giran sin peso",
                "Glúteos asentados",
            },
            "exv2_ab_wheel_rollout": {
                "Rueda abdominal con aro visible",
                "Rodilla principal fija",
            },
        }
        for ex_id, expected_names in requirements.items():
            with self.subTest(exercise=ex_id):
                path = self.root / f"assets/exercise_media/lottie/{ex_id}.json"
                doc = json.loads(path.read_text(encoding="utf-8"))
                layer_names = {layer["nm"] for layer in doc["layers"]}
                self.assertTrue(expected_names.issubset(layer_names))
                self.assertGreaterEqual(
                    sum(layer["shapes"][0]["it"][0]["ks"]["a"] == 1
                        for layer in doc["layers"]), 3)
                self.assertFalse(any(name.startswith(("Rig ", "Base ",
                                                    "Estructura "))
                                     for name in layer_names))

    def test_second_visual_qa_group_has_six_distinct_anatomical_landmarks(self):
        requirements = {
            "exv2_bird_dog": {"view": "lateral", "landmarks": [
                "Mano de apoyo siempre fija", "Muslo pierna libre se extiende atrás",
                "Húmero contralateral se proyecta adelante"]},
            "exv2_side_plank": {"view": "lateral", "landmarks": [
                "Pie superior apilado", "Codo de apoyo debajo hombro",
                "Cintura activa respira sin bajar pelvis"]},
            "exv2_incline_rear_delt_fly": {"view": "lateral", "landmarks": [
                "Banco inclinado acolchado en diagonal",
                "Pecho realmente apoyado en banco", "Mancuerna mano cercana"]},
            "exv2_cable_external_rotation": {"view": "frontal", "landmarks": [
                "Codo estabilizado a 90 grados",
                "Antebrazo rota hacia fuera sin trasladar codo",
                "Cable sigue agarre desde polea"]},
            "exv2_dead_bug": {"view": "lateral", "landmarks": [
                "Colchoneta supina", "Pelvis en apoyo de suelo",
                "Brazo opuesto alcanza arriba",
                "Muslo contralateral extiende pierna"]},
            "exv2_band_pallof": {"view": "lateral", "landmarks": [
                "Cadera cuadrada estable", "Banda elástica lateral gana tensión",
                "Antebrazos empujan desde esternón"]},
        }
        manifest = json.loads((self.root / "tool/exercise_lottie_batches.json")
                              .read_text(encoding="utf-8"))
        manifest_items = {item["id"]: item
                          for batch in manifest["batches"]
                          for item in batch["items"]}
        self.assertEqual(len(requirements), 6)
        for ex_id, config in requirements.items():
            with self.subTest(exercise=ex_id):
                doc = json.loads((self.root /
                    f"assets/exercise_media/lottie/{ex_id}.json")
                    .read_text(encoding="utf-8"))
                item = manifest_items[ex_id]
                self.assertEqual(item["view"], config["view"])
                self.assertEqual(item["status"], "draft")
                self.assertIs(item["approved"], False)
                self.assertTrue(all(not v for v in item["review"].values()))
                self.assertIn(f" / {ex_id} / {config['view']} / ", doc["nm"])
                names = {layer["nm"] for layer in doc["layers"]}
                self.assertTrue(set(config["landmarks"]).issubset(names))
                self.assertGreaterEqual(sum(
                    layer["shapes"][0]["it"][0]["ks"]["a"] == 1
                    for layer in doc["layers"]), 3)
                self.assertFalse(any(name.startswith(("Rig ", "Base ",
                    "Estructura ")) and name.split()[-1].isdigit()
                    for name in names))

    def test_malformed_keyframe_topology_rejected(self):
        keys = {"a": 1, "k": [
            {"t": 0, "s": [{"v": [[1, 2], [3, 4]]}],
             "e": [{"v": [[2, 3]]}]},
            {"t": 30, "s": [{"v": [[2, 3]]}]},
        ]}
        with self.assertRaises(ValueError):
            frame_value(keys, 15)


if __name__ == "__main__":
    unittest.main()
