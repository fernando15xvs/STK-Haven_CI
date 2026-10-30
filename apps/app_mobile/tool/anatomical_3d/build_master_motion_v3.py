#!/usr/bin/env python3
"""Reusable 55-joint master motion clips with glTF morph-weight drivers.

Internal authoring rig QA, NOT approved biomechanics, NOT Flutter playback.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from retarget_cc0_glb import GLB, qmul, qnorm
from build_master_surface_v2 import CORRECTIVE_SPEC

FRAMES=41
DURATION=4.
MORPH_KEYS=tuple(kind+"_"+side for kind in CORRECTIVE_SPEC for side in ("l","r"))
PATTERNS={
  "overhead_reach_bilateral":{
    "joints":{"upperarm_l":("z",65),"upperarm_r":("z",-65),
              "stk_scapula_control_l":("x",12),"stk_scapula_control_r":("x",12)},
    "drivers":{"scapular_elevation_l":.85,"scapular_elevation_r":.85}},
  "unilateral_reach_left":{
    "joints":{"upperarm_l":("z",58),"stk_scapula_control_l":("x",10)},
    "drivers":{"scapular_elevation_l":.8}},
  "unilateral_reach_right":{
    "joints":{"upperarm_r":("z",-58),"stk_scapula_control_r":("x",10)},
    "drivers":{"scapular_elevation_r":.8}},
  "bilateral_elbow_curl":{
    "joints":{"lowerarm_l":("x",88),"lowerarm_r":("x",88)},
    "drivers":{"elbow_flexion_l":.95,"elbow_flexion_r":.95}},
  "hip_hinge":{
    "joints":{"spine_01":("x",31),"thigh_l":("x",-25),"thigh_r":("x",-25)},
    "drivers":{"hip_flexion_l":.62,"hip_flexion_r":.62}},
  "squat_articulation":{
    "joints":{"thigh_l":("x",-46),"thigh_r":("x",-46),
              "calf_l":("x",68),"calf_r":("x",68),"spine_01":("x",9)},
    "drivers":{"hip_flexion_l":.8,"hip_flexion_r":.8,
               "knee_flexion_l":.85,"knee_flexion_r":.85}},
  "split_lunge_left":{
    "joints":{"thigh_l":("x",-42),"calf_l":("x",62),
              "thigh_r":("x",18),"calf_r":("x",22)},
    "drivers":{"hip_flexion_l":.8,"hip_flexion_r":.33,
               "knee_flexion_l":.85,"knee_flexion_r":.28}}
}
MAX_JOINT_DEG=105

def quaternion(axis,degrees):
    h=math.radians(degrees)/2
    s=math.sin(h)
    if axis=="x": return qnorm((s,0.,0.,math.cos(h)))
    if axis=="y": return qnorm((0.,s,0.,math.cos(h)))
    if axis=="z": return qnorm((0.,0.,s,math.cos(h)))
    raise ValueError("Invalid local joint axis")

def ease(p):
    if not 0.<=p<=1.:
        raise ValueError("Outside animation phase")
    return p*p*(3-2*p)

def phase(t):
    if t<=0. or t>=DURATION:return 0.
    if t<1.6:return ease(t/1.6)
    if t<=2.4:return 1.
    return ease((DURATION-t)/1.6)

def validate_pattern(glb,name,pattern):
    for bone,(axis,angle) in pattern["joints"].items():
        if bone not in glb.by_name or axis not in ("x","y","z"):
            raise ValueError("Unknown joint or local axis: "+bone)
        if abs(angle)>MAX_JOINT_DEG:
            raise ValueError("Preview angular limit exceeded: "+bone)
    for label,strength in pattern["drivers"].items():
        if label not in MORPH_KEYS or not 0.<=strength<=1.:
            raise ValueError("Unknown or overdriven morph target: "+label)
        kind,side=label.rsplit("_",1)
        joint={"scapular_elevation":"stk_scapula_control",
               "elbow_flexion":"lowerarm","hip_flexion":"thigh",
               "knee_flexion":"calf"}[kind]+"_"+side
        if joint not in pattern["joints"]:
            raise ValueError("Corrective has no moving joint: "+label)
    if name.startswith("unilateral_reach_"):
        inactive="r" if name.endswith("left") else "l"
        if any(k.endswith("_"+inactive) for k in pattern["joints"]):
            raise ValueError("Contralateral arm altered in unilateral pattern")

def construct(data):
    original_sha=hashlib.sha256(data).hexdigest()
    glb=GLB(data,expected_sha=None)
    doc=glb.doc
    extras=doc.get("extras",{})
    if (extras.get("surfaceVersion")!=2 or
        extras.get("sourceSha256")!="7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749"
        or extras.get("approved") is not False or extras.get("enabled") is not False
        or len(doc["skins"][0]["joints"])!=55 or doc.get("animations")):
        raise ValueError("Expected neutral unapproved 55-joint v2 master")
    mesh=doc["meshes"][0]
    if (tuple(mesh["extras"].get("targetNames",[]))!=MORPH_KEYS or
        mesh.get("weights")!=[0.]*8):
        raise ValueError("Inactive corrective index order differs from master v2")
    bodies=[i for i,n in enumerate(glb.nodes)
            if n.get("mesh")==0 and n.get("skin")==0]
    if len(bodies)!=1:raise ValueError("One skinned body node required")
    body_node=bodies[0]
    times=[round(DURATION*i/(FRAMES-1),7) for i in range(FRAMES)]
    time_id=glb.append(times,1,"SCALAR")
    clips=[]
    summaries={}
    for label,pattern in PATTERNS.items():
        validate_pattern(glb,label,pattern)
        channels=[]
        samplers=[]
        def channel(node,path,values,components):
            accessor=glb.append(values,components,
              "VEC4" if components==4 else "SCALAR")
            slot=len(samplers)
            samplers.append({"input":time_id,"output":accessor,
                             "interpolation":"LINEAR"})
            channels.append({"sampler":slot,"target":{"node":node,"path":path}})
        for bone,(axis,degrees) in pattern["joints"].items():
            idx=glb.by_name[bone]
            rest=tuple(glb.nodes[idx].get("rotation",(0.,0.,0.,1.)))
            output=[qnorm(qmul(rest,quaternion(axis,degrees*phase(t))))
                    for t in times]
            for k in range(1,len(output)):
                if sum(a*b for a,b in zip(output[k-1],output[k]))<0:
                    output[k]=tuple(-x for x in output[k])
            channel(idx,"rotation",output,4)
        values=[]
        for t in times:
            p=phase(t)
            values.extend(pattern["drivers"].get(key,0.)*p for key in MORPH_KEYS)
        # glTF 2.0 animation morph weights require flattened SCALAR samples.
        channel(body_node,"weights",values,1)
        clips.append({"name":"STK_MASTER_"+label+"_UNAPPROVED",
            "samplers":samplers,"channels":channels,
            "extras":{"pattern":label,"approved":False,
                      "hasFootIK":False,"equipmentCollisionChecked":False,
                      "biomechanicsReviewed":False}})
        summaries[label]={"durationSeconds":DURATION,
            "keyframes":FRAMES,"jointNames":list(pattern["joints"]),
            "activeMorphTargets":list(pattern["drivers"]),
            "morphDriverConnected":True,
            "footContactValidated":False,"approved":False,"enabled":False}
    doc["animations"]=clips
    doc["extras"]=dict(extras,masterMotionVersion=3,
        sourceMasterSurfaceSha256=original_sha,
        previewPatternCount=len(clips),approved=False,enabled=False,
        status="rig_pattern_review_not_equipment_or_biomechanics_approved")
    report={"version":3,"sourceMasterSurfaceSha256":original_sha,
       "sourceLicense":"CC0-1.0","joints":55,"morphTargets":8,
       "patternCount":len(clips),"patterns":summaries,"catalogCount":229,
       "approved":False,"enabled":False,"productionReady":False,
       "knownLimits":["No inverse-kinematic planted feet",
          "No cable, bar, bench or equipment contact constraints",
          "No anatomist-approved segmented muscles",
          "Morph drivers are procedural, not professionally sculpted",
          "Current Flutter CPU player does not yet animate glTF morph weights",
          "No on-device GPU, FPS, CPU, battery or biomechanics sign-off"]}
    return glb.bytes(),report

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    args=p.parse_args()
    raw,manifest=construct(args.input.read_bytes())
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"stk_master_55_motion_lab_v3_unapproved.glb").write_bytes(raw)
    (args.output/"master_motion_v3_report.json").write_text(
       json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print(json.dumps({"status":"unapproved_pose_lab","bytes":len(raw),
      "patterns":manifest["patternCount"],"morphTargets":8,
      "approved":False,"enabled":False},indent=2))
if __name__=="__main__":main()
