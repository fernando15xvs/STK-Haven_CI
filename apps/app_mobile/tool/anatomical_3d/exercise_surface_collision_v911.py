#!/usr/bin/env python3
"""v9.11 OFFLINE conservative surface/equipment proximity audit for 3 master55 clips.

This is sampled geometric evidence, NOT continuous mesh contact/collision
certification or professional biomechanical/clinical approval.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, SOURCE_SHA, qrot

FPS=30
FRAMES=121
VERTEX_SAMPLES=384
MAX_MESH_BYTES=1400*1024


def capped_cylinder_sdf(point,a,b,radius):
    """Signed distance to a finite X-axis cylinder, negative inside."""
    if not 0<radius<=.2 or b<=a:
        raise ValueError("Invalid QA cylinder")
    x,y,z=point
    center=(a+b)/2.
    radial=math.hypot(y,z)-radius
    axial=abs(x-center)-(b-a)/2.
    return min(max(radial,axial),0.)+math.hypot(max(radial,0.),max(axial,0.))


def box_sdf(point,lower,upper):
    """Signed distance to an axis-aligned closed bounding box."""
    if any(b<=a for a,b in zip(lower,upper)):
        raise ValueError("Invalid QA box")
    centered=[(a+b)/2. for a,b in zip(lower,upper)]
    extent=[(b-a)/2. for a,b in zip(lower,upper)]
    d=[abs(p-c)-h for p,c,h in zip(point,centered,extent)]
    return math.sqrt(sum(max(0.,v)**2 for v in d))+min(max(d),0.)


def _slerp(a,b,t):
    dot=sum(x*y for x,y in zip(a,b))
    if dot<0:
        b=tuple(-v for v in b);dot=-dot
    if dot>.9995:
        q=tuple(x*(1-t)+y*t for x,y in zip(a,b))
    else:
        angle=math.acos(max(-1.,min(1.,dot)))
        q=tuple((math.sin((1-t)*angle)*x+math.sin(t*angle)*y)/
                math.sin(angle) for x,y in zip(a,b))
    length=math.sqrt(sum(x*x for x in q))
    if length<1e-10:raise ValueError("Invalid interpolated quaternion")
    return tuple(x/length for x in q)


def _samplers(glb):
    clip=glb.doc["animations"][0]
    out={}
    for channel in clip["channels"]:
        sample=clip["samplers"][channel["sampler"]]
        target=channel["target"]
        key=(target["node"],target["path"])
        if key in out or sample.get("interpolation")!="LINEAR":
            raise ValueError("Invalid QA animation channel")
        times=[t[0] for t in glb.accessor(sample["input"])]
        values=glb.accessor(sample["output"])
        if len(times)!=41 or any(abs(t-i*.1)>1e-5
                                  for i,t in enumerate(times)):
            raise ValueError("Expected 4-second pilot timeline")
        if len(values)!=(328 if target["path"]=="weights" else 41):
            raise ValueError("Invalid pilot attribute samples")
        out[key]=values
    return out


def _sample(glb,channels,seconds):
    k=min(39,int(seconds*10))
    mix=max(0.,min(1.,(seconds-k*.1)/.1))
    local={}
    weight_values=None
    for (node,path),values in channels.items():
        if path=="weights":
            weight_values=[
                values[k*8+j][0]*(1-mix)+
                values[(k+1)*8+j][0]*mix for j in range(8)]
            continue
        before,after=values[k],values[k+1]
        value=_slerp(before,after,mix) if path=="rotation" else tuple(
            x*(1-mix)+y*mix for x,y in zip(before,after))
        obj=glb.nodes[node]
        position,rotation=local.get(node,(
            tuple(obj.get("translation",(0,0,0))),
            tuple(obj.get("rotation",(0,0,0,1)))))
        if path=="rotation":rotation=value
        else:position=value
        local[node]=(position,rotation)
    if weight_values is None or len(weight_values)!=8:
        raise ValueError("Missing eight corrective drivers")
    world,rotations=glb.world(local)
    return world,rotations,weight_values


def _skin_vertex(position,deltas,weights,joints,ibm,world,rotations,
                 joint_nodes,activation):
    p=[position[i]+sum(activation[m]*deltas[m][i] for m in range(8))
       for i in range(3)]
    out=[0.,0.,0.]
    for weight,index in zip(weights,joints):
        if weight<1e-7:continue
        if not 0<=index<len(joint_nodes):
            raise ValueError("Vertex influence outside master skin")
        m=ibm[index]
        bind=(m[0]*p[0]+m[4]*p[1]+m[8]*p[2]+m[12],
              m[1]*p[0]+m[5]*p[1]+m[9]*p[2]+m[13],
              m[2]*p[0]+m[6]*p[1]+m[10]*p[2]+m[14])
        joint=joint_nodes[index]
        moved=qrot(rotations[joint],bind)
        for i in range(3):
            out[i]+=weight*(world[joint][i]+moved[i])
    if not all(math.isfinite(v) for v in out):
        raise ValueError("Nonfinite skinned surface point")
    return tuple(out)


def _equipment_boxes(glb):
    names={m.get("name"):m for m in glb.doc["meshes"]}
    if "STK_BENCH_STATIC" not in names:return []
    boxes=[]
    for part in names["STK_BENCH_STATIC"]["primitives"]:
        points=glb.accessor(part["attributes"]["POSITION"])
        boxes.append((tuple(min(p[i] for p in points) for i in range(3)),
                      tuple(max(p[i] for p in points) for i in range(3))))
    return boxes


def _bar_sdf(point,bar):
    x,y,z=(point[i]-bar[i] for i in range(3))
    pieces=[(-1.1,1.1,.019),(-.93,-.87,.17),(.87,.93,.17),
            (-.508,-.492,.022),(.492,.508,.022),
            (-.86,-.81,.044),(.81,.86,.044)]
    return min(capped_cylinder_sdf((x,y,z),a,b,r) for a,b,r in pieces)


def review(raw,exercise):
    if exercise not in EXERCISES:raise ValueError("Unknown exercise")
    if len(raw)>MAX_MESH_BYTES:raise ValueError("QA mesh budget exceeded")
    glb=GLB(raw,expected_sha=None)
    ex=glb.doc.get("extras",{})
    if (ex.get("masterExercisePilotVersion")!=910 or
        ex.get("exerciseId")!=exercise or
        ex.get("sourceSha256")!=SOURCE_SHA or
        ex.get("approved") is not False or ex.get("enabled") is not False or
        len(glb.doc["skins"][0]["joints"])!=55 or
        len(glb.doc["meshes"][0]["primitives"])!=12 or
        len(glb.doc["animations"])!=1 or
        "STK_EXERCISE_BAR" not in glb.by_name):
        raise ValueError("Only disabled 55-bone exercise candidates accepted")
    parts=glb.doc["meshes"][0]["primitives"]
    original=parts[0]["attributes"]
    positions=glb.accessor(original["POSITION"])
    joints=glb.accessor(original["JOINTS_0"])
    weights=glb.accessor(original["WEIGHTS_0"])
    deltas=[glb.accessor(t["POSITION"]) for t in parts[0]["targets"]]
    ibm=glb.accessor(glb.doc["skins"][0]["inverseBindMatrices"])
    skin_nodes=glb.doc["skins"][0]["joints"]
    if not all(len(x)==len(positions) for x in [joints,weights,*deltas]):
        raise ValueError("Incomplete skinned/morph geometry")
    stride=max(1,len(positions)//VERTEX_SAMPLES)
    selected=list(range(0,len(positions),stride))[:VERTEX_SAMPLES]
    if len(selected)<100:raise ValueError("Insufficient mesh surface samples")
    channels=_samplers(glb)
    boxes=_equipment_boxes(glb)
    if (exercise=="ex_bench_press")!=bool(boxes):
        raise ValueError("Static bench geometry must match press pilot")
    stats={
        "samples":0,"sampledBarProximityUnder25mm":0,
        "possibleBarPenetrationsAwayFromWrists":0,
        "possibleBenchProxyPenetrations":0,
        "sampledGroundPenetrations":0,
        "minBarSignedDistanceMeters":float("inf"),
        "minBenchSignedDistanceMeters":float("inf"),
        "minBodyHeightMeters":float("inf"),
    }
    for frame in range(FRAMES):
        world,rot,activation=_sample(glb,channels,frame/FPS)
        bar=world[glb.by_name["STK_EXERCISE_BAR"]]
        wrists=[world[glb.by_name["hand_"+side]] for side in ("l","r")]
        for index in selected:
            point=_skin_vertex(positions[index],
                [d[index] for d in deltas],weights[index],
                joints[index],ibm,world,rot,skin_nodes,activation)
            d=_bar_sdf(point,bar)
            stats["samples"]+=1
            stats["minBarSignedDistanceMeters"]=min(
                d,stats["minBarSignedDistanceMeters"])
            stats["minBodyHeightMeters"]=min(
                point[1],stats["minBodyHeightMeters"])
            if d<.025:stats["sampledBarProximityUnder25mm"]+=1
            # The wrist joint is only a coarse grip-zone landmark.
            if d<-.002 and min(math.dist(point,w) for w in wrists)>.12:
                stats["possibleBarPenetrationsAwayFromWrists"]+=1
            if point[1]<-.006:stats["sampledGroundPenetrations"]+=1
            for lo,hi in boxes:
                sep=box_sdf(point,lo,hi)
                stats["minBenchSignedDistanceMeters"]=min(
                    sep,stats["minBenchSignedDistanceMeters"])
                if sep<-.002:stats["possibleBenchProxyPenetrations"]+=1
    if stats["samples"]!=FRAMES*len(selected):
        raise ValueError("Incomplete collision review sampling")
    for key in ("minBarSignedDistanceMeters","minBodyHeightMeters"):
        stats[key]=round(stats[key],6)
    if not boxes:stats["minBenchSignedDistanceMeters"]=None
    else:stats["minBenchSignedDistanceMeters"]=round(
        stats["minBenchSignedDistanceMeters"],6)
    return {
        "exerciseId":exercise,"frames":FRAMES,
        "skinnedPointsPerFrame":len(selected),
        "skinningJointCount":55,"morphTargetCount":8,
        "barPiecesChecked":7,"benchProxyParts":len(boxes),
        "metrics":stats,
        "collisionFindingsAreApproximate":True,
        "collisionFreeCertified":False,
        "expertAnatomyReviewed":False,
        "physicalDeviceReviewed":False,
        "approved":False,"enabled":False,
        "manualBlockers":[
            "Sparse vertex sampling may miss narrow penetrations",
            "Skin topology/intersections and full capsule-to-triangle CCD absent",
            "Bar/end grip contacts only approximate; finger mesh not tested",
            "Bench cushion tissue compression and shoe-floor contacts unresolved",
        ],
    }


def build(folder,output):
    root=Path(folder);out=Path(output)
    out.mkdir(parents=True,exist_ok=True)
    results=[review(
        (root/(name+"_master55_v910_scapular_qa.glb")).read_bytes(),name)
        for name in EXERCISES]
    report={
        "schema":"stk_master55_surface_collision_v911_QA_only",
        "approved":False,"enabled":False,"catalogCount":229,
        "samplesPerExercise":FRAMES,
        "scope":"sparse skinned/morphed surface to rigid proxy signed distances",
        "reviewFindingsRequireHuman":True,"pilots":results,
    }
    (out/"surface_collision_v911.json").write_text(
        json.dumps(report,indent=2)+"\n",encoding="utf8")
    return report
