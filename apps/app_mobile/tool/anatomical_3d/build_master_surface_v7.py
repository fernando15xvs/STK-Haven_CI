#!/usr/bin/env python3
"""Disabled v7 CC0 LOD muscle-volume pass: pectoral/deltoid/back forms.

This is a reproducible, bounded procedural artist preview. It does NOT create
individually sculpted muscles, certify anatomy or enable app animations.
The same 55 bones, 7 motions, 8 morphs and 12 anatomical region primitives
are preserved. No new buffers/textures; mobile GLB remains <= 850 KiB.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
from retarget_cc0_glb import GLB
from build_master_surface_v2 import cross, sub, recompute_normals
from build_master_surface_v6 import (BUDGET_BYTES, MORPH_NAMES, topology,
                                    replace_accessor)

REGION_RELIEF_METERS = {
    "pectoralis_major": .00125,
    "anterior_deltoid": .00105,
    "posterior_deltoid": .00105,
    "latissimus_dorsi": .00095,
    "rhomboids": .00065,
    "middle_trapezius": .00065,
}
MAX_VERTEX_EDIT_METERS = .0015
MIN_TRIANGLE_AREA2 = 1e-12
SIDE_CUTOFF = .015

def norm(v):
    return math.sqrt(sum(x*x for x in v))

def smoothstep(t):
    t=max(0.,min(1.,t))
    return t*t*(3.-2.*t)

def weighted_profile(points, region_votes, side):
    active=[(points[i],float(w)) for i,w in enumerate(region_votes)
            if w>0 and (points[i][0]>SIDE_CUTOFF if side=="l"
                        else points[i][0]<-SIDE_CUTOFF)]
    denominator=sum(w for _,w in active)
    if denominator<=0:raise ValueError("Empty bilateral muscle side: "+side)
    center=tuple(sum(p[k]*w for p,w in active)/denominator for k in range(3))
    scale=tuple(max(.040,math.sqrt(sum((p[k]-center[k])**2*w
                    for p,w in active)/denominator)*1.8) for k in range(3))
    return center,scale

def region_votes(glb, vertex_count):
    names=set(REGION_RELIEF_METERS)
    hits={name:[0]*vertex_count for name in names}
    total=[0]*vertex_count
    faces={}
    for primitive in glb.doc["meshes"][0]["primitives"]:
        name=primitive["extras"]["stkMuscleRegion"]
        triangles=[int(t[0]) for t in glb.accessor(primitive["indices"])]
        if len(triangles)%3:raise ValueError("Bad region triangles")
        faces[name]=triangles
        for vertex in triangles:
            if vertex<0 or vertex>=vertex_count:
                raise ValueError("Region vertex index out of bounds")
            total[vertex]+=1
            if name in hits:hits[name][vertex]+=1
    if set(faces)!={"body"}|set((
        "pectoralis_major","anterior_deltoid","posterior_deltoid",
        "triceps_brachii","latissimus_dorsi","rhomboids",
        "middle_trapezius","quadriceps_femoris","gluteus_maximus",
        "hamstrings","adductor_magnus")):
        raise ValueError("Wrong CC0 region atlas")
    votes={name:[hit/max(1,count) for hit,count in zip(data,total)]
           for name,data in hits.items()}
    return votes,faces

def detail(points,normals,votes,graph):
    """Subtle bilateral Gaussian bellies tapered at region boundaries.

    The simulated shape is geometric relief only, not a fiber/tendon model.
    Clamp by local triangle edge length to avoid high-frequency folds.
    """
    if len(points)!=len(normals) or len(graph)!=len(points):
        raise ValueError("Surface attribute size mismatch")
    masks={}
    for name,original in votes.items():
        mask=list(original)
        for _ in range(2):
            mask=[
                .68*value + .32*(sum(mask[j]*w for j,w in graph[i].items())/
                                  sum(graph[i].values()))
                if graph[i] else value
                for i,value in enumerate(mask)
            ]
        masks[name]=mask
    centers={(name,side):weighted_profile(points,votes[name],side)
             for name in REGION_RELIEF_METERS for side in ("l","r")}
    output=[]
    largest=0.
    edited=0
    for i,(point,normal) in enumerate(zip(points,normals)):
        x=point[0]
        if abs(x)<SIDE_CUTOFF:
            output.append(tuple(point))
            continue
        side="l" if x>0 else "r"
        amplitude=0.
        for name,maximum in REGION_RELIEF_METERS.items():
            center,scale=centers[name,side]
            r2=sum(((point[k]-center[k])/scale[k])**2 for k in range(3))
            lobe=math.exp(-.8*r2)
            amplitude+=maximum*lobe*smoothstep(masks[name][i])
        # Fine geometry in small LOD triangles may not tolerate millimeters.
        lengths=[norm(sub(points[j],point)) for j in graph[i]
                 if norm(sub(points[j],point))>1e-5]
        local_cap=min(MAX_VERTEX_EDIT_METERS,
                      .10*min(lengths) if lengths else 0.)
        amplitude=min(amplitude,local_cap)
        amplitude*=smoothstep((abs(x)-SIDE_CUTOFF)/.035)
        normal_size=norm(normal)
        if not math.isfinite(amplitude) or normal_size<.7 or normal_size>1.3:
            raise ValueError("Invalid sculpt normal or amplitude")
        moved=tuple(point[k]+normal[k]/normal_size*amplitude
                    for k in range(3))
        output.append(moved)
        largest=max(largest,norm(sub(moved,point)))
        if norm(sub(moved,point))>.00002:edited+=1
    if largest>MAX_VERTEX_EDIT_METERS+1e-7 or edited<100:
        raise ValueError("Insufficient or unsafe CC0 authoring detail")
    return output,{"maxEditMeters":round(largest,7),
                   "editedVertices":edited,
                   "perRegionLimitMeters":REGION_RELIEF_METERS,
                   "bilateralMirroredProfiles":True}

def face_orientation(original,changed,faces):
    """Reject triangle folds; this checks topology, not clinical plausibility."""
    flipped=0
    triangles=0
    for indices in faces.values():
        for i in range(0,len(indices),3):
            a,b,c=indices[i:i+3]
            old=cross(sub(original[b],original[a]),
                      sub(original[c],original[a]))
            new=cross(sub(changed[b],changed[a]),
                      sub(changed[c],changed[a]))
            if norm(old)>MIN_TRIANGLE_AREA2 and norm(new)>MIN_TRIANGLE_AREA2:
                if sum(x*y for x,y in zip(old,new))<=0:flipped+=1
            triangles+=1
    if flipped:raise ValueError("Sculpt inverted %d faces"%flipped)
    return triangles

def sculpt(raw):
    glb=GLB(raw,expected_sha=None)
    doc=glb.doc
    extra=doc.get("extras",{})
    if (extra.get("masterSurfaceContinuityVersion")!=6
        or extra.get("masterCorrectiveDriverVersion")!=2
        or extra.get("approved") is not False
        or extra.get("enabled") is not False
        or len(doc.get("skins",[]))!=1
        or len(doc["skins"][0]["joints"])!=55
        or len(doc.get("animations",[]))!=7
        or len(doc.get("meshes",[]))!=1
        or len(doc["meshes"][0]["primitives"])!=12
        or tuple(doc["meshes"][0]["extras"].get("targetNames",()))!=MORPH_NAMES):
        raise ValueError("v7 requires the disabled, audited v6 master")
    primitives=doc["meshes"][0]["primitives"]
    attrs=primitives[0]["attributes"]
    if any(p["attributes"]!=attrs or
           p["targets"]!=primitives[0]["targets"] for p in primitives):
        raise ValueError("Mesh streams are not shared")
    original=glb.accessor(attrs["POSITION"])
    normals=glb.accessor(attrs["NORMAL"])
    joints=glb.accessor(attrs["JOINTS_0"])
    weights=glb.accessor(attrs["WEIGHTS_0"])
    if not 1000<len(original)<10000:
        raise ValueError("Wrong mobile vertex budget")
    votes,faces=region_votes(glb,len(original))
    graph=topology(glb,original,joints,weights)
    refined,metrics=detail(original,normals,votes,graph)
    triangles=face_orientation(original,refined,faces)
    adjusted_normals=recompute_normals(normals,refined,faces)
    if len(adjusted_normals)!=len(original) or any(
            abs(norm(n)-1)>.002 for n in adjusted_normals):
        raise ValueError("Invalid sculpt vertex normals")
    replace_accessor(glb,attrs["POSITION"],refined)
    replace_accessor(glb,attrs["NORMAL"],adjusted_normals)
    doc["extras"]=dict(extra,masterSculptDetailVersion=7,
        approved=False,enabled=False,
        detailStatus="procedural_artist_preview_not_anatomist_reviewed")
    output=glb.bytes()
    if len(output)>BUDGET_BYTES:raise ValueError("v7 exceeds mobile budget")
    report={"version":7,"sourceVersion":6,"joints":55,
            "clips":7,"morphTargets":8,"regionPrimitives":12,
            "catalogCount":229,"triangleCount":triangles,
            "sourceBytes":len(raw),"bytes":len(output),
            "metrics":metrics,"regionsEnhanced":list(REGION_RELIEF_METERS),
            "approved":False,"enabled":False,
            "productionReady":False,"anatomyCertified":False,
            "knownLimitations":[
                "Procedural millimeter relief, not an independent muscle sculpt",
                "No tendon or fascia topology, skeletal measurement or clinical signoff",
                "No GPU skinning or on-device performance certificate"]}
    return output,report

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--input",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    raw,report=sculpt(args.input.read_bytes())
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"stk_master_v7_surface_preview.glb").write_bytes(raw)
    (args.output/"master_surface_v7_report.json").write_text(
        json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print(json.dumps({k:report[k] for k in
        ("version","bytes","catalogCount","approved","enabled")},indent=2))

if __name__=="__main__":main()
