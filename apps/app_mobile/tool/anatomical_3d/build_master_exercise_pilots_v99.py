#!/usr/bin/env python3
"""Retarget the three existing CC0 exercise pilots to the 55-joint v7 master.

This creates NEW unapproved offline QA derivatives. It never modifies the
53-joint source, 55-joint master, the app bundle, or the 229 exercise records.
The two extra shoulder controls remain neutral until IK is re-solved for them.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, EXERCISES, SOURCE_SHA
from build_master_contacts_v5 import MORPH_NAMES, corrective_weights

MASTER_NAME="stk_master_v7_surface_preview.glb"
MAX_QA_GLb_BYTES=1400*1024
TIMES=41
DURATION_SECONDS=4.

def _valid_inputs(master,pilot,exercise):
    me=master.doc.get("extras",{})
    pe=pilot.doc.get("extras",{})
    if exercise not in EXERCISES:
        raise ValueError("Unknown stable pilot exercise ID")
    if (me.get("masterSculptDetailVersion")!=7 or
        me.get("sourceSha256")!=SOURCE_SHA or
        me.get("approved") is not False or me.get("enabled") is not False or
        len(master.doc.get("skins",[]))!=1 or
        len(master.doc["skins"][0]["joints"])!=55 or
        len(master.doc.get("animations",[]))!=7 or
        len(master.doc.get("meshes",[]))!=1):
        raise ValueError("Require unapproved master v7 55-joint CC0 derivative")
    mesh=master.doc["meshes"][0]
    if (len(mesh["primitives"])!=12 or
        tuple(mesh.get("extras",{}).get("targetNames",[]))!=MORPH_NAMES):
        raise ValueError("Require 11 master muscle regions and eight morphs")
    if (pe.get("exerciseId")!=exercise or
        pe.get("sourceSha256")!=SOURCE_SHA or
        pe.get("approved") is not False or pe.get("enabled") is not False or
        len(pilot.doc.get("skins",[]))!=1 or
        len(pilot.doc["skins"][0]["joints"])!=53 or
        len(pilot.doc.get("animations",[]))!=1):
        raise ValueError("Require disabled 53-joint exercise-specific source")
    if "STK_EXERCISE_BAR" not in pilot.by_name:
        raise ValueError("Missing pilot equipment joint")
    old=pilot.doc["animations"][0]
    if not old["channels"] or len(old["samplers"])<10:
        raise ValueError("Incomplete pilot animation")
    if any(x.get("interpolation")!="LINEAR" for x in old["samplers"]):
        raise ValueError("Pilot must have LINEAR glTF sampler channels")
    for name in ("stk_scapula_control_l","stk_scapula_control_r"):
        if name not in master.by_name or name in pilot.by_name:
            raise ValueError("55-bone pivot contract violated")

def _add_equipment(master,pilot,exercise):
    """Deep-copy rigid meshes and all their nodes into the master scene.

    Re-encodes only referenced geometry/materials. No original skin or morph
    accessor is changed. A node attached to the root scene stays unskinned.
    """
    node_map={}
    material_map={}
    selected=("STK_BAR_AND_PLATES","STK_BENCH_STATIC")
    for source_index,source_node in enumerate(pilot.nodes):
        mesh_index=source_node.get("mesh")
        if mesh_index is None:continue
        source_mesh=pilot.doc["meshes"][mesh_index]
        if source_mesh.get("name") not in selected:continue
        if source_mesh.get("name")=="STK_BENCH_STATIC" and exercise!="ex_bench_press":
            raise ValueError("Unexpected bench in standing pilot")
        mesh=copy.deepcopy(source_mesh)
        copied=[]
        for primitive in source_mesh["primitives"]:
            fields=primitive.get("attributes",{})
            if set(fields)!={"POSITION","NORMAL"} or primitive.get("mode",4)!=4:
                raise ValueError("Unexpected skinned/unsupported equipment mesh")
            p=pilot.accessor(fields["POSITION"])
            n=pilot.accessor(fields["NORMAL"])
            ind=[int(v[0]) for v in pilot.accessor(primitive["indices"])]
            if not p or len(p)!=len(n) or len(ind)%3 or (
                min(ind)<0 or max(ind)>=len(p)):
                raise ValueError("Malformed rigid equipment")
            for values in (p,n):
                if not all(all(math.isfinite(v) for v in row) for row in values):
                    raise ValueError("Nonfinite equipment geometry")
            source_material=primitive["material"]
            if source_material not in material_map:
                material=copy.deepcopy(pilot.doc["materials"][source_material])
                material["name"]="STK_PILOT_"+material["name"]
                material_map[source_material]=len(master.doc["materials"])
                master.doc["materials"].append(material)
            part=copy.deepcopy(primitive)
            part["attributes"]={
                "POSITION":master.append(p,3,"VEC3",target=34962),
                "NORMAL":master.append(n,3,"VEC3",target=34962),
            }
            part["indices"]=master.append(ind,1,"SCALAR",component=5123,
                                           target=34963)
            part["material"]=material_map[source_material]
            copied.append(part)
        mesh["primitives"]=copied
        destination_mesh=len(master.doc["meshes"])
        master.doc["meshes"].append(mesh)
        node=copy.deepcopy(source_node)
        if node.get("children") or "skin" in node:
            raise ValueError("Equipment is not an isolated rigid root node")
        node["mesh"]=destination_mesh
        destination_node=len(master.nodes)
        master.nodes.append(node)
        master.by_name[node["name"]]=destination_node
        master.doc["scenes"][master.doc.get("scene",0)]["nodes"].append(
            destination_node)
        node_map[source_index]=destination_node
    expected=2 if exercise=="ex_bench_press" else 1
    if len(node_map)!=expected:
        raise ValueError("Missing or duplicated rigid equipment nodes")
    return node_map

def _copy_animation(master,pilot,equipment_nodes,exercise):
    old=pilot.doc["animations"][0]
    samplers=[]
    channels=[]
    times=None
    rotations={}
    for channel in old["channels"]:
        original=old["samplers"][channel["sampler"]]
        path=channel["target"]["path"]
        src_node=channel["target"]["node"]
        name=pilot.nodes[src_node].get("name")
        if src_node in equipment_nodes:
            dst_node=equipment_nodes[src_node]
        elif name in master.by_name:
            dst_node=master.by_name[name]
        else:
            raise ValueError("Old 53-bone channel does not match master: "+str(name))
        if path not in ("rotation","translation"):
            raise ValueError("Unexpected exercise channel type")
        clock=[x[0] for x in pilot.accessor(original["input"])]
        values=pilot.accessor(original["output"])
        if (len(clock)!=TIMES or len(values)!=TIMES or
            any(abs(t-i*.1)>1e-5 for i,t in enumerate(clock)) or
            not all(math.isfinite(v) for row in values for v in row)):
            raise ValueError("Pilot channel sample/timing is corrupted")
        if times is None:times=master.append(clock,1,"SCALAR")
        if path=="rotation":
            if any(len(v)!=4 or abs(sum(x*x for x in v)-1.)>.002
                   for v in values):
                raise ValueError("Nonunit glTF pilot rotation")
            rotations[dst_node]=values
        component=4 if path=="rotation" else 3
        ai=master.append(values,component,"VEC4" if component==4 else "VEC3")
        channels.append({"sampler":len(samplers),
                         "target":{"node":dst_node,"path":path}})
        samplers.append({"input":times,"output":ai,"interpolation":"LINEAR"})
    if not rotations or times is None:
        raise ValueError("Pilot has no skeletal animation")
    # The eight correctives are driven by the actual corresponding joint
    # rotation tracks; shoulder controls have no automated motion yet.
    weights=[]
    strongest={name:0. for name in MORPH_NAMES}
    for k in range(TIMES):
        local={}
        for node,poses in rotations.items():
            local[node]=(
                tuple(master.nodes[node].get("translation",(0,0,0))),
                tuple(poses[k]),
            )
        driver=corrective_weights(master,local,{})
        if set(driver)!=set(MORPH_NAMES):
            raise ValueError("Missing master eight corrective channels")
        for name in MORPH_NAMES:
            value=driver[name]
            if not math.isfinite(value) or not 0<=value<=1.025:
                raise ValueError("Morph activation out of bounds")
            strongest[name]=max(value,strongest[name])
            weights.append(value)
    # Morph animation's target is the master skinned-mesh node. glTF requires
    # an output SCALAR for each of the eight weights at every keyframe.
    mesh_nodes=[index for index,node in enumerate(master.nodes)
                if node.get("mesh")==0 and "skin" in node]
    if len(mesh_nodes)!=1:
        raise ValueError("Expected exactly one master skinned mesh node")
    weight_output=master.append(weights,1,"SCALAR")
    channels.append({"sampler":len(samplers),
        "target":{"node":mesh_nodes[0],"path":"weights"}})
    samplers.append({"input":times,"output":weight_output,
                     "interpolation":"LINEAR"})
    # These two new shoulder controls are intentionally left neutral:
    # rotating them without resolving wrist IK would destroy bar grip.
    clip={"name":"STK_MASTER_55_"+exercise+"_V99_UNAPPROVED",
          "samplers":samplers,"channels":channels,
          "extras":{"exerciseId":exercise,"approved":False,
                    "biomechanicsReviewed":False,
                    "scapularMotionIKSolved":False,
                    "morphsDrivenByBoneExcursion":True}}
    return clip,strongest

def convert(master_bytes,pilot_bytes,exercise):
    master=GLB(master_bytes,expected_sha=None)
    pilot=GLB(pilot_bytes,expected_sha=None)
    _valid_inputs(master,pilot,exercise)
    original_skin=copy.deepcopy(master.doc["skins"])
    original_regions=copy.deepcopy(master.doc["meshes"][0])
    equipment=_add_equipment(master,pilot,exercise)
    clip,weights=_copy_animation(master,pilot,equipment,exercise)
    master.doc["animations"]=[clip]
    master.doc["extras"]=dict(master.doc["extras"],
        exerciseId=exercise,masterExercisePilotVersion=99,
        sourceExerciseRigJoints=53,outputMasterRigJoints=55,
        approved=False,enabled=False,
        contactAndExpertReviewPending=True,
        anatomyProfessional=False,physicalDeviceValidated=False)
    # Never mutate the 55-bone skin, surface, original morph/region accessors.
    if master.doc["skins"]!=original_skin or (
        master.doc["meshes"][0]!=original_regions):
        raise ValueError("Master anatomical skin or surface was altered")
    built=master.bytes()
    if len(built)>MAX_QA_GLb_BYTES:
        raise ValueError("Offline 55-bone QA pilot exceeded budget")
    result={
        "exerciseId":exercise,"outputBytes":len(built),
        "outputSha256":hashlib.sha256(built).hexdigest(),
        "sourceMasterSha256":hashlib.sha256(master_bytes).hexdigest(),
        "sourcePilotSha256":hashlib.sha256(pilot_bytes).hexdigest(),
        "outputRigJoints":55,"sourceRigJoints":53,
        "regionPrimitives":12,"morphTargetCount":8,
        "morphPeakWeights":weights,"rigControlsStillNeutral":True,
        "equipmentMeshCount":len(equipment),
        "frames":TIMES,"durationSeconds":DURATION_SECONDS,
        "approved":False,"enabled":False,
        "manualBlockers":[
            "55-bone wrist/contact IK must be re-solved and sampled at 30 FPS",
            "Shoulder girdle controls require realistic calibrated motion",
            "Skin and equipment collision detection not implemented",
            "Professional anatomy/biomechanics signoff missing",
            "iPhone and Android physical visual/performance QA missing",
        ],
    }
    return built,result

def build(master_file,source_folder,output_folder):
    master=Path(master_file).read_bytes()
    out=Path(output_folder);out.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        pilot=(Path(source_folder)/(exercise+"_mobile_lod.glb")).read_bytes()
        body,report=convert(master,pilot,exercise)
        (out/(exercise+"_master55_v99_unapproved.glb")).write_bytes(body)
        reports.append(report)
    manifest={"version":99,"type":"exercise_specific_55_joint_QA_not_production",
              "catalogCount":229,"approved":False,"enabled":False,
              "sources":["master_CC0_55_v7","pilot_CC0_53_v9_8"],
              "pilots":reports}
    (out/"three_pilot_master55_v99.json").write_text(
        json.dumps(manifest,indent=2)+"\n",encoding="utf8")
    return manifest

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--master",type=Path,required=True)
    parser.add_argument("--pilots",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    a=parser.parse_args()
    print(json.dumps(build(a.master,a.pilots,a.output),indent=2))
