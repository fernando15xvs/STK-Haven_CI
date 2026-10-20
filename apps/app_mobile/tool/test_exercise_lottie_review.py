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
