"""Offline video pipeline contracts, deterministic refusal of missing frames."""
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import encode_video_comparison as exporter

class VideoComparisonTest(unittest.TestCase):
    def test_four_second_h264_can_be_generated_without_gifs(self):
        if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
            self.skipTest("ffmpeg/ffprobe unavailable")
        with tempfile.TemporaryDirectory() as tmp:
            directory=pathlib.Path(tmp)
            frames=directory/"frames"
            glbs=directory/"glb"
            glbs.mkdir()
            for exercise in exporter.IDS:
                target=frames/exercise
                target.mkdir(parents=True)
                subprocess.run(["ffmpeg","-loglevel","error","-y",
                    "-f","lavfi","-i","color=c=blue:s=320x320:r=16:d=4",
                    "-frames:v","64",str(target/"frame_%03d.png")],check=True)
                (glbs/(exercise+".glb")).write_bytes(b"glTF"*100)
            report=exporter.encode(frames,directory/"videos",glbs)
            self.assertEqual(report["catalogCount"],229)
            self.assertFalse(report["approved"])
            self.assertFalse(report["enabled"])
            self.assertEqual(len(report["pilots"]),3)
            self.assertTrue(all(x["codec"]=="h264" and
                3.9<=x["durationSeconds"]<=4.1 for x in report["pilots"]))
            self.assertFalse(list((directory/"videos").glob("*.gif")))
    def test_missing_capture_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                exporter.encode(pathlib.Path(tmp),pathlib.Path(tmp)/"out",
                                pathlib.Path(tmp))
if __name__=="__main__":
    unittest.main()
