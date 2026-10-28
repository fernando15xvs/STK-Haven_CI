"""Basic offline QA for three distinct transparent PNG sequences."""
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from generate_pilots import IDS, PHASES, build

class PilotPngTest(unittest.TestCase):
    def test_all_twelve_transparent_frames_are_distinct(self):
        with tempfile.TemporaryDirectory() as t:
            result=build(t)
            self.assertEqual(set(result),set(IDS))
            for name in IDS:
                hashes=set()
                for phase in PHASES:
                    path=Path(t)/name/(phase+".png")
                    with Image.open(path) as im:
                        self.assertEqual(im.format,"PNG")
                        self.assertEqual(im.size,(480,500))
                        self.assertEqual(im.mode,"RGBA")
                        self.assertEqual(im.getpixel((0,0))[3],0)
                        self.assertGreater(im.getchannel("A").getbbox()[2],300)
                        hashes.add(path.read_bytes())
                self.assertEqual(len(hashes),4)
    def test_deterministic_png_output(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            build(a);build(b)
            for ex in IDS:
                for phase in PHASES:
                    self.assertEqual((Path(a)/ex/(phase+".png")).read_bytes(),
                                     (Path(b)/ex/(phase+".png")).read_bytes())

if __name__=="__main__":
    unittest.main()
