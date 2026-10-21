"""Audit actual exported glTF LINEAR channels at 30 FPS, not just IK keys.

Check hand-to-bar grip, planted feet, and the last/first frame seam.
This is geometric contact QA only, never biomechanical certification.
"""
import bisect
import json
import math
import os
import unittest
from pathlib import Path

import retarget_cc0_glb as rig

OUT = Path(os.environ.get("STK_CC0_RETARGET", "build/cc0_53bone_retarget"))
FPS = 30
SAMPLES = 121
MAX_ERROR = .005  # 5 millimetres: deliberately strict but not zero.


def slerp(a, b, factor):
    dot = sum(x*y for x, y in zip(a, b))
    if dot < 0:
        b = tuple(-x for x in b)
        dot = -dot
    if dot > .9995:
        return rig.qnorm(tuple(x*(1-factor)+y*factor for x, y in zip(a, b)))
    angle = math.acos(min(1., max(-1., dot)))
    return tuple(
        (math.sin((1-factor)*angle)*x + math.sin(factor*angle)*y)/math.sin(angle)
        for x, y in zip(a, b)
    )


def world_at(glb, seconds, tracks):
    local = {}
    for node, path, times, values in tracks:
        i = max(0, min(len(times)-2, bisect.bisect_right(times, seconds)-1))
        fraction = max(0., min(1., (seconds-times[i])/(times[i+1]-times[i])))
        a, b = values[i], values[i+1]
        sample = slerp(a, b, fraction) if path == "rotation" else tuple(
            x*(1-fraction)+y*fraction for x, y in zip(a, b))
        record = glb.nodes[node]
        translation, rotation = local.get(node, (
            tuple(record.get("translation", (0, 0, 0))),
            tuple(record.get("rotation", (0, 0, 0, 1)))))
        if path == "rotation":
            rotation = sample
        else:
            translation = sample
        local[node] = (translation, rotation)
    positions, _ = glb.world(local)
    return positions


def sample_30fps(exercise):
    glb = rig.GLB((OUT/(exercise+"_mobile_lod.glb")).read_bytes(),
                  expected_sha=None)
    clip = glb.doc["animations"][0]
    tracks = []
    for channel in clip["channels"]:
        sampler = clip["samplers"][channel["sampler"]]
        times = [x[0] for x in glb.accessor(sampler["input"])]
        frames = glb.accessor(sampler["output"])
        if sampler["interpolation"] != "LINEAR" or len(times) != len(frames):
            raise ValueError("Expected complete GLB LINEAR animation")
        tracks.append((channel["target"]["node"],
                       channel["target"]["path"], times, frames))
    first = world_at(glb, 0, tracks)
    bar_index = glb.by_name["STK_EXERCISE_BAR"]
    max_grip = max_foot = 0.
    for frame in range(SAMPLES):
        sample = world_at(glb, frame/FPS, tracks)
        for side, sign in (("l",1),("r",-1)):
            wrist = sample[glb.by_name["hand_"+side]]
            bar = sample[bar_index]
            grip = (bar[0]+sign*(.51 if exercise=="ex_squat" else .50),
                    bar[1],bar[2])
            max_grip = max(max_grip, math.dist(wrist,grip))
            index = glb.by_name["foot_"+side]
            max_foot = max(max_foot, math.dist(sample[index],first[index]))
    last = world_at(glb, 4, tracks)
    loop = max(math.dist(first[glb.by_name[j]],last[glb.by_name[j]])
               for j in ("hand_l","hand_r","foot_l","foot_r","head"))
    return {
        "exerciseId":exercise,"frames":SAMPLES,"fps":FPS,
        "maximumHandGripErrorMeters":round(max_grip,7),
        "maximumFootDriftMeters":round(max_foot,7),
        "loopSeamMeters":round(loop,7),
        "approved":False,"enabled":False,
        "review":"geometric interpolation only, not expert biomechanics"
    }


class GlbBetweenKeyframesTest(unittest.TestCase):
    def test_three_glb_motion_clips_interpolate_without_slipping(self):
        report = []
        for exercise in rig.EXERCISES:
            result = sample_30fps(exercise)
            self.assertEqual(result["frames"],121)
            self.assertLess(result["maximumHandGripErrorMeters"],MAX_ERROR,result)
            self.assertLess(result["maximumFootDriftMeters"],MAX_ERROR,result)
            self.assertLess(result["loopSeamMeters"],.00001,result)
            report.append(result)
        (OUT/"interpolated_contact_30fps.json").write_text(json.dumps({
            "status":"experimental_review_only",
            "approved":False,"enabled":False,
            "samplesPerExercise":SAMPLES,
            "clips":report},indent=2)+"\n",encoding="utf8")

if __name__ == "__main__":
    unittest.main()
