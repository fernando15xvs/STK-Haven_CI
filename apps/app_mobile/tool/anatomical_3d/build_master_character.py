#!/usr/bin/env python3
"""Build the first reusable STK Haven humanoid MASTER asset, not an exercise.

Uses the audited CC0 53-joint Innerscene mesh, adds two functional scapular
control pivots (55 joints), and exports 11 independent muscle-region index
groups. All original skin vertices, 53 original bind matrices, and source
mesh topology are retained. A neutral pose without animations/equipment is
the authoritative master from which *future* reviewed exercises may derive.

This is a rig/semantic-preparation pass, NOT a professional muscle sculpt.
"""
import argparse
from collections import Counter,defaultdict
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, qconj, qrot, sub, qnorm
from muscle_region_atlas import region_for_face, EXERCISE_ROLES

SOURCE_ID="innerscene_cc0_rig53"
MASTER_VERSION=1
SIDES=("l","r")

def quat_to_inverse_mat4(position,rotation):
    """Column-major glTF inverse-bind matrix for a unit-scale rest joint."""
    x,y,z,w=qnorm(qconj(rotation))
    xx,yy,zz=x*x,y*y,z*z
    xy,xz,yz=x*y,x*z,y*z
    wx,wy,wz=w*x,w*y,w*z
    a=1-2*(yy+zz);b=2*(xy-wz);c=2*(xz+wy)
    d=2*(xy+wz);e=1-2*(xx+zz);f=2*(yz-wx)
    g=2*(xz-wy);h=2*(yz+wx);i=1-2*(xx+yy)
    tx=-(a*position[0]+b*position[1]+c*position[2])
    ty=-(d*position[0]+e*position[1]+f*position[2])
    tz=-(g*position[0]+h*position[1]+i*position[2])
    return (a,d,g,0,b,e,h,0,c,f,i,0,tx,ty,tz,1)

def _unit_rig(glb):
    # Base meshes export tiny numerical scale noise on a few bones; the
    # preview rig uses unit-scale rigid quaternion joints only.
    for node in glb.nodes:
        scale=node.get("scale")
        if scale is not None:
            if len(scale)!=3 or any(abs(float(s)-1)>1e-4 for s in scale):
                raise ValueError("CC0 master has nonunit scale requiring rebind")
            del node["scale"]

def add_scapular_controls(glb):
    """Insert l/r shoulder-girdle controls without moving existing bind pose.

    New pivot is a child of spine_03 and parent of the original clavicle.
    The original clavicle translation is expressed relative to that pivot.
    The additional 2 bones are skinless influence-wise; rotating them moves
    the original weighted clavicle + arm subtree by FK. Scapular geometry
    itself is not separately sculpted or skin-weighted.
    """
    old_skin=glb.doc["skins"][0]
    old_joints=list(old_skin["joints"])
    if len(old_joints)!=53:
        raise ValueError("Expected original 53-bone skinned CC0 model")
    spine=glb.by_name["spine_03"]
    original_ibm=glb.accessor(old_skin["inverseBindMatrices"])
    if len(original_ibm)!=53:
        raise ValueError("Unexpected source inverse bind matrices")
    extra_ibm=[]
    controls={}
    for side in SIDES:
        clav=glb.by_name["clavicle_"+side]
        if glb.parents[clav]!=spine:
            raise ValueError("Clavicle bind parenting differs from verified source")
        clav_local=tuple(glb.nodes[clav].get("translation",(0,0,0)))
        sign=1 if side=="l" else -1
        # Inside scapular plane: posterior and lateral to the upper thorax.
        pivot_local=(sign*.095,.210,-.105)
        control=len(glb.nodes)
        glb.nodes.append({"name":"stk_scapula_control_"+side,
                          "translation":list(pivot_local),
                          "rotation":[0,0,0,1],
                          "children":[clav],
                          "extras":{"stkRole":"shoulder_girdle",
                              "source":"STK_derivative_control_not_anatomical_sculpt",
                              "side":side,
                              "allowedLocalRotationDegrees":{"x":[-15,20],
                                  "y":[-20,20],"z":[-20,20]}}})
        glb.nodes[spine]["children"].remove(clav)
        glb.nodes[spine]["children"].append(control)
        glb.nodes[clav]["translation"]=[
            a-b for a,b in zip(clav_local,pivot_local)]
        glb.parents[clav]=control
        glb.parents[control]=spine
        glb.by_name["stk_scapula_control_"+side]=control
        position=tuple(a+b for a,b in zip(glb.restpos[spine],
                qrot(glb.restrot[spine],pivot_local)))
        rotation=glb.restrot[spine]
        extra_ibm.append(quat_to_inverse_mat4(position,rotation))
        controls[side]={"name":"stk_scapula_control_"+side,
                        "node":control,"jointIndex":len(old_joints)-1,
                        "parentNode":spine,"clavicleNode":clav,
                        "position":list(position)}
        old_joints.append(control)
    old_skin["joints"]=old_joints
    old_skin["inverseBindMatrices"]=glb.append(
        original_ibm+extra_ibm,16,"MAT4")
    return controls

def build_rest_anatomy_groups(glb):
    """Retain every original triangle, assigning one of 11 neutral labels."""
    primitive=glb.doc["meshes"][0]["primitives"][0]
    points=glb.accessor(primitive["attributes"]["POSITION"])
    normals=glb.accessor(primitive["attributes"]["NORMAL"])
    joins=glb.accessor(primitive["attributes"]["JOINTS_0"])
    weights=glb.accessor(primitive["attributes"]["WEIGHTS_0"])
    original=[int(v[0]) for v in glb.accessor(primitive["indices"])]
    names={glb.nodes[node]["name"]:i
           for i,node in enumerate(glb.doc["skins"][0]["joints"])}
    allowed=set().union(*(set(v) for v in EXERCISE_ROLES.values()))
    groups=defaultdict(list)
    sides=defaultdict(lambda:[0,0])
    for offset in range(0,len(original),3):
        face=original[offset:offset+3]
        center=tuple(sum(points[i][axis] for i in face)/3 for axis in range(3))
        surface=tuple(sum(normals[i][axis] for i in face)/3 for axis in range(3))
        joint_indices=[value for i in face for value in joins[i]]
        joint_weights=[value/3 for i in face for value in weights[i]]
        name=region_for_face(center,surface,joint_indices,joint_weights,names)
        if name not in allowed:name="body"
        groups[name].extend(face)
        sides[name][0 if center[0]<0 else 1]+=1
    if set(groups)!=allowed|{"body"}:
        raise ValueError("Incomplete anatomical region coverage: "+str(set(groups)))
    if sum(len(v) for v in groups.values())!=len(original):
        raise ValueError("Original face count changed")
    glb.doc["materials"][0]["name"]="STK_BODY"
    glb.doc["materials"][0]["extras"]={"stkMuscleRole":"body"}
    glb.doc["materials"].append({
      "name":"STK_MUSCLE_NEUTRAL",
      "extras":{"stkMuscleRole":"muscle_neutral"},
      "doubleSided":True,
      "pbrMetallicRoughness":{"baseColorFactor":[.67,.70,.73,1],
           "metallicFactor":0,"roughnessFactor":.77}})
    new_primitives=[]
    for name in ["body"]+sorted(allowed):
        import copy
        p=copy.deepcopy(primitive)
        p["indices"]=glb.append(groups[name],1,"SCALAR",component=5125,target=34963)
        p["material"]=0 if name=="body" else 1
        p["extras"]={"stkMuscleRegion":name,
                     "reviewed":False,
                     "classification":"approximate_skin_normal_bind_pose",
                     "releaseAllowed":False}
        new_primitives.append(p)
    glb.doc["meshes"][0]["primitives"]=new_primitives
    glb.doc["meshes"][0]["name"]="STK_HUMAN_MASTER_CC0_55_BONES"
    return {name:{"triangles":len(groups[name])//3,
                  "left":sides[name][0],"right":sides[name][1],
                  "anatomistApproved":False} for name in groups}

def contract(controls,regions,sha):
    """Explicitly distinguish supporting controls from approved abilities."""
    return {
      "schemaVersion":1,"masterVersion":MASTER_VERSION,
      "assetId":"stk_haven_cc0_humanoid_master_55",
      "license":"CC0-1.0","sourceAssetId":SOURCE_ID,"sourceSha256":sha,
      "originalJointCount":53,"masterJointCount":55,
      "originalTriangles":107024,"anatomicalRegionCount":11,
      "approved":False,"enabled":False,"catalogCount":229,
      "rigControls":{"scapula":controls,
          "forearmTwist":{"implemented":False},
          "correctiveBlendshapes":{"implemented":False}},
      "muscleRegionGroups":regions,
      "exerciseBindings":{},
      "patternReadiness":{
         "horizontal_push":"needs_motion_and_coach_review",
         "vertical_push":"unverified",
         "horizontal_pull":"needs_motion_and_coach_review",
         "vertical_pull":"unverified",
         "squat":"needs_motion_and_coach_review",
         "hip_hinge":"unverified",
         "lunge":"unverified",
         "elbow_flexion":"unverified",
         "elbow_extension":"unverified",
         "shoulder_abduction":"unverified",
         "unilateral":"unverified",
         "seated":"unverified",
         "lying":"needs_motion_and_coach_review"
      },
      "blockers":[
         "Professional muscular sculpt is absent",
         "Muscle classification masks are approximate, not anatomy-validated",
         "Shoulder blades are rig controls but not separately sculpted",
         "Corrective joint deformers and forearm twist not implemented",
         "Biomechanics and equipment collision not certified",
         "Mobile GPU rendering and device benchmarks pending"
      ]
    }

def master_from_cc0(data):
    glb=GLB(data) # SHA256-pinned public-domain source
    _unit_rig(glb)
    controls=add_scapular_controls(glb)
    regions=build_rest_anatomy_groups(glb)
    glb.doc["animations"]=[]
    glb.doc["extras"]={"sourceSha256":hashlib.sha256(data).hexdigest(),
       "assetId":"stk_haven_cc0_humanoid_master_55",
       "masterVersion":MASTER_VERSION,
       "approved":False,"enabled":False,
       "catalogCount":229,
       "status":"rig_semantics_draft_not_anatomy_complete"}
    out=glb.bytes()
    return out,contract(controls,regions,hashlib.sha256(data).hexdigest())

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--input",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    raw,profile=master_from_cc0(args.input.read_bytes())
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"stk_haven_master_55_unapproved.glb").write_bytes(raw)
    (args.output/"master_character_profile.json").write_text(
      json.dumps(profile,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps({"status":"draft_master_generated","bytes":len(raw),
      "bones":55,"regions":11,"approved":False,"enabled":False},indent=2))
if __name__=="__main__":
    main()
