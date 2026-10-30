#!/usr/bin/env python3
"""Conservative scapular-control IK correction on three disabled master55 GLBs.

Works on v9.9 exercise-specific 55-bone derivatives. Does not edit the 53-joint
source, the master neutral GLB, or any application/catalog asset.

Contact is defined ONLY at wrist/ankle joints (not finger/skin surface).
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, SOURCE_SHA, sub, norm
from build_master_contacts_v5 import (
    MORPH_NAMES, SIDES, phase, rotate_local_z, two_link,
    corrective_weights,
)

TIMES=41
FPS=30
CLIP_DURATION=4.0
# Mild previews, NOT validated scapulohumeral rhythms or clinical angles.
MAX_EXCURSION_DEG={
    "ex_bench_press":1.4,
    "ex_barbell_row":2.8,
    "ex_squat":0.65,
}
MAX_KEYFRAME_WRIST_ERROR_METERS=.001
MAX_SCAPULAR_BONE_DEGREES=3.0
# v9.9 outputs are offline source of truth, not new master geometry.
MAX_GLb_BYTES=1400*1024

def _channel_samples(glb,clip):
    outputs={}
    for channel in clip["channels"]:
        sampler=clip["samplers"][channel["sampler"]]
        node=channel["target"]["node"]
        kind=channel["target"]["path"]
        if sampler.get("interpolation")!="LINEAR":
            raise ValueError("Cannot change non-LINEAR preview animation")
        ticks=[v[0] for v in glb.accessor(sampler["input"])]
        if len(ticks)!=TIMES or any(abs(t-i/10)>1e-5 for i,t in enumerate(ticks)):
            raise ValueError("Expected exactly 41 0.1-second keyframes")
        samples=glb.accessor(sampler["output"])
        if kind=="weights":
            if len(samples)!=TIMES*8:raise ValueError("Malformed eight morphs")
        elif kind in ("rotation","translation"):
            if len(samples)!=TIMES:
                raise ValueError("Malformed joint channel")
        else:
            raise ValueError("Unexpected glTF channel")
        key=(node,kind)
        if key in outputs:raise ValueError("Conflicting glTF node channels")
        outputs[key]=(channel,sampler,samples)
    return outputs

def _local_at(glb,record,frame):
    local={}
    for (node,kind),(_,_,samples) in record.items():
        if kind=="weights":continue
        original=glb.nodes[node]
        position,rotation=local.get(node,(
            tuple(original.get("translation",(0.,0.,0.))),
            tuple(original.get("rotation",(0.,0.,0.,1.)))))
        if kind=="translation":position=samples[frame]
        else:rotation=samples[frame]
        local[node]=(tuple(position),tuple(rotation))
    return local

def _try_side(glb,baseline,side,wrist_target,pole,angle_radians):
    """Re-solve shoulder/elbow with the scapular pivot rotated.

    Returns the selected safe local pose or None. A failed IK step is never
    committed, and an unreachable target does not corrupt the animation.
    """
    if abs(angle_radians)<1e-9:return None
    for factor in (1.,.5,.25,.125):
        candidate=dict(baseline)
        rotate_local_z(glb,candidate,
            "stk_scapula_control_"+side,angle_radians*factor)
        try:
            two_link(glb,candidate,"upperarm_"+side,"lowerarm_"+side,
                "hand_"+side,wrist_target,pole)
            world,_=glb.world(candidate)
            error=norm(sub(world[glb.by_name["hand_"+side]],wrist_target))
            if error<=MAX_KEYFRAME_WRIST_ERROR_METERS:
                return candidate,angle_radians*factor,error
        except (ValueError,ZeroDivisionError,OverflowError):
            continue
    return None

def correct(raw,exercise):
    if exercise not in EXERCISES:raise ValueError("Unknown pilot ID")
    glb=GLB(raw,expected_sha=None)
    meta=glb.doc.get("extras",{})
    if (meta.get("masterExercisePilotVersion")!=99 or
        meta.get("exerciseId")!=exercise or
        meta.get("sourceSha256")!=SOURCE_SHA or
        meta.get("approved") is not False or
        meta.get("enabled") is not False or
        len(glb.doc["skins"][0]["joints"])!=55 or
        len(glb.doc["meshes"][0]["primitives"])!=12 or
        len(glb.doc["animations"])!=1):
        raise ValueError("Expected disabled v9.9 55-bone exercise GLB")
    if "stk_scapula_control_l" not in glb.by_name or (
            "stk_scapula_control_r" not in glb.by_name):
        raise ValueError("Master shoulder controls missing")
    clip=glb.doc["animations"][0]
    channels=_channel_samples(glb,clip)
    targets={}
    controlled=("upperarm_l","lowerarm_l","upperarm_r","lowerarm_r")
    for name in controlled:
        index=glb.by_name[name]
        if (index,"rotation") not in channels:
            raise ValueError("Missing articulated source pilot arm: "+name)
    counts={"l":0,"r":0}
    reductions={"l":0,"r":0}
    peak={"l":0.,"r":0.}
    worst={"l":0.,"r":0.}
    keys={name:[] for name in controlled}
    pivots={side:[] for side in SIDES}
    weights=[]
    max_non_arm_change=0.
    for frame in range(TIMES):
        t=frame/10.
        pose=_local_at(glb,channels,frame)
        base,_=glb.world(pose)
        for side in SIDES:
            hand="hand_"+side
            shoulder="upperarm_"+side
            elbow="lowerarm_"+side
            desired=base[glb.by_name[hand]]
            # The original elbow direction fixes the bend plane; preserving
            # it avoids flipping the elbow while solving a new shoulder.
            pole=sub(base[glb.by_name[elbow]],
                     base[glb.by_name[shoulder]])
            sign=1. if side=="l" else -1.
            angle=sign*math.radians(MAX_EXCURSION_DEG[exercise])*phase(t)
            solution=_try_side(glb,pose,side,desired,pole,angle)
            if solution is None:
                pivots[side].append(tuple(
                    glb.nodes[glb.by_name["stk_scapula_control_"+side]]
                    .get("rotation",(0.,0.,0.,1.))))
                reductions[side]+=int(abs(angle)>1e-9)
            else:
                corrected,accepted,err=solution
                pose=corrected
                counts[side]+=1
                peak[side]=max(peak[side],abs(math.degrees(accepted)))
                worst[side]=max(worst[side],err)
                pivots[side].append(pose[
                    glb.by_name["stk_scapula_control_"+side]][1])
        current,_=glb.world(pose)
        for side in SIDES:
            worst[side]=max(worst[side],norm(sub(
                current[glb.by_name["hand_"+side]],
                base[glb.by_name["hand_"+side]])))
        for name in controlled:
            node=glb.by_name[name]
            rotation=pose.get(node,(
                tuple(glb.nodes[node].get("translation",(0.,0.,0.))),
                tuple(glb.nodes[node].get("rotation",(0.,0.,0.,1.)))))[1]
            keys[name].append(rotation)
        driver=corrective_weights(glb,pose,{})
        if set(driver)!=set(MORPH_NAMES):
            raise ValueError("Broken eight-corrective channel order")
        weights.extend(driver[key] for key in MORPH_NAMES)
    if not all(0<=peak[s]<=MAX_SCAPULAR_BONE_DEGREES for s in SIDES):
        raise ValueError("Exceeded scapular preview joint excursion")
    if not all(worst[s]<MAX_KEYFRAME_WRIST_ERROR_METERS for s in SIDES):
        raise ValueError("Scapular IK changed equipment grip too much")
    if any(not math.isfinite(w) or w<0 or w>1.025 for w in weights):
        raise ValueError("Unsafe corrective morph")
    if not any(counts.values()):
        raise ValueError("Shoulder IK did not solve any moving pose")

    for name,samples in keys.items():
        node=glb.by_name[name]
        _,sampler,_=channels[(node,"rotation")]
        sampler["output"]=glb.append(samples,4,"VEC4")
    time_access=next(iter(channels.values()))[1]["input"]
    for side,samples in pivots.items():
        # Include the new rig controls as explicit channels with continuous
        # 41-frame interpolation. These must remain within the local rotation
        # boundaries of the master authoring profile.
        node=glb.by_name["stk_scapula_control_"+side]
        output=glb.append(samples,4,"VEC4")
        clip["channels"].append({"sampler":len(clip["samplers"]),
            "target":{"node":node,"path":"rotation"}})
        clip["samplers"].append({"input":time_access,"output":output,
                                "interpolation":"LINEAR"})
    weight_channels=[ch for ch in clip["channels"]
                     if ch["target"]["path"]=="weights"]
    if len(weight_channels)!=1:
        raise ValueError("Expected exactly one master morph channel")
    source=clip["samplers"][weight_channels[0]["sampler"]]
    source["output"]=glb.append(weights,1,"SCALAR")
    clip["name"]="STK_MASTER_55_"+exercise+"_V910_IK_UNAPPROVED"
    clip["extras"]=dict(clip.get("extras",{}),
        scapularMotionIKSolved=True,scapularAnglesAreClinical=False,
        barContactSurfaceTested=False,biomechanicsReviewed=False,
        approved=False,enabled=False)
    glb.doc["extras"]=dict(meta,masterExercisePilotVersion=910,
        derivedFromReviewVersion=99,scapulaPreviewIKCorrected=True,
        approved=False,enabled=False,anatomyProfessional=False,
        contactAndExpertReviewPending=True)
    out=glb.bytes()
    if len(out)>MAX_GLb_BYTES:
        raise ValueError("55-bone IK QA asset exceeds offline budget")
    return out,{
        "exerciseId":exercise,"inputSha256":__import__("hashlib").sha256(raw).hexdigest(),
        "keyframes":TIMES,"targetFramesPerSecond":FPS,
        "maxContactErrorAtKeysMeters":worst,
        "solvedIKKeys":counts,"reducedOrUnsolvedKeys":reductions,
        "peakScapularLocalDegrees":peak,
        "eightMorphDrivers":True,"physicalDeviceMeasured":False,
        "surfaceCollisionValidated":False,"clinicalAnglesCertified":False,
        "approved":False,"enabled":False,
    }

def build(folder,output):
    folder=Path(folder);destination=Path(output)
    destination.mkdir(parents=True,exist_ok=True)
    summaries=[]
    for exercise in EXERCISES:
        source=(folder/(exercise+"_master55_v99_unapproved.glb")).read_bytes()
        raw,summary=correct(source,exercise)
        (destination/(exercise+"_master55_v910_scapular_qa.glb")).write_bytes(raw)
        summaries.append(summary)
    report={"schema":"stk_master55_scapular_v910_unapproved",
            "rigJointCount":55,"exerciseCount":3,"catalogCount":229,
            "approved":False,"enabled":False,"pilots":summaries,
            "limitations":[
                "Original CC0 movement targets remain preliminary",
                "Only wrist joint target positions are IK constrained",
                "Skin/finger/bar/bench collision and visual anatomy pending",
                "Scapular angular limits are QA heuristics, not clinical data",
                "Continuous interpolation must be independently verified",
            ]}
    (destination/"scapular_qa_v910_report.json").write_text(
        json.dumps(report,indent=2)+"\n",encoding="utf8")
    return report

if __name__=="__main__":
    a=argparse.ArgumentParser()
    a.add_argument("--pilots",type=Path,required=True)
    a.add_argument("--output",type=Path,required=True)
    parsed=a.parse_args()
    print(json.dumps(build(parsed.pilots,parsed.output),indent=2))
