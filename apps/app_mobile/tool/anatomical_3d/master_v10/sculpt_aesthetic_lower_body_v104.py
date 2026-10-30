#!/usr/bin/env python3
"""v10.4 STK Haven: athletic proportions, natural legs and reduced hard cuts.

Independent QA-only authoring mesh, *not* exercise media. Corrects the
v10.3 excessive thigh/calf/glute volume, swollen deltoids, angular pectorals,
chin bulges, and overly strong 3D abdominal etching. Bilateral and symmetric.
No claim of artist review, rig, UV, textures, animation or production quality.
"""
from __future__ import annotations
import argparse
from dataclasses import replace
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from skimage.measure import marching_cubes
import trimesh
from build_master_silhouette_v10 import _composite
from sculpt_arms_hands_v103 import shaped_arms, _arm_channels
from sculpt_torso_back_v102 import _surface_anatomy

VERSION=104
# All units are meters. V10.3 was deliberately exaggerated; these changes
# remove bulk from the upper-body and leg silhouette, rather than adding mm
# micro-reliefs. Kept symmetric to permit future skinning.
AESTHETIC_OVERRIDES={
    'core_ribcage':dict(radius_x=.267,radius_z=.155,blend=.042),
    'core_waist':dict(radius_x=.191,radius_z=.128,blend=.045),
    'core_pelvis':dict(radius_x=.194,radius_y=.166,blend=.044),
    'neck':dict(center_y=1.597,radius_x=.073,radius_z=.069,blend=.033),
    'head_cranium':dict(center_y=1.742,radius_x=.104,radius_y=.136,
                        radius_z=.103,blend=.025),
    'head_jaw':dict(center_y=1.681,center_z=.014,radius_x=.087,
                    radius_y=.082,radius_z=.092,blend=.027),
    'head_nose':dict(center_y=1.715,center_z=.098,radius_x=.013,
                     radius_y=.025,radius_z=.017,blend=.013),
    'head_chin':dict(center_y=1.643,center_z=.059,radius_x=.040,
                     radius_y=.021,radius_z=.025,blend=.021),
    'pectoral_major':dict(center_x=.134,center_y=1.436,center_z=.102,
                          radius_x=.144,radius_y=.084,radius_z=.054,blend=.037),
    'pectoralis_clavicular':dict(center_x=.161,center_z=.102,
                                 radius_x=.104,radius_y=.046,radius_z=.042,
                                 blend=.030),
    'upper_trapezius':dict(center_x=.173,center_y=1.545,radius_x=.149,
                           radius_y=.075,radius_z=.061,blend=.038),
    'deltoid_lateral':dict(center_x=.345,center_y=1.454,
                           radius_x=.082,radius_y=.085,radius_z=.078,
                           blend=.037),
    'deltoid_anterior':dict(center_x=.333,center_y=1.442,
                            radius_x=.060,radius_y=.081,radius_z=.062,
                            blend=.037),
    'deltoid_posterior':dict(center_x=.338,center_y=1.440,
                             radius_x=.064,radius_y=.081,radius_z=.064,
                             blend=.038),
    'latissimus_dorsi':dict(center_x=.204,center_z=-.090,
                            radius_x=.098,radius_y=.182,radius_z=.068,
                            blend=.042),
    'rhomboid':dict(center_z=-.135,radius_x=.082,radius_y=.095,
                    radius_z=.037,blend=.031),
    'serratus_anterior':dict(radius_x=.056,radius_y=.099,
                             radius_z=.048,blend=.035),
    'external_oblique':dict(center_z=.054,radius_x=.067,
                            radius_y=.139,radius_z=.050,blend=.045),
    'rectus_abdominis_1':dict(radius_x=.051,radius_y=.041,
                              radius_z=.018,blend=.032),
    'rectus_abdominis_2':dict(radius_x=.049,radius_y=.039,
                              radius_z=.017,blend=.032),
    'rectus_abdominis_3':dict(radius_x=.048,radius_y=.037,
                              radius_z=.016,blend=.032),
    'upper_arm':dict(center_x=.467,radius_x=.072,radius_y=.187,
                     radius_z=.066,blend=.041),
    'biceps_brachii':dict(center_x=.466,radius_x=.050,radius_y=.128,
                          radius_z=.043,blend=.043),
    'triceps':dict(center_x=.470,radius_x=.055,radius_y=.146,
                   radius_z=.042,blend=.040),
    'elbow':dict(center_x=.577,radius_x=.044,radius_y=.060,
                 radius_z=.046,blend=.037),
    'forearm':dict(center_x=.689,radius_x=.056,radius_y=.160,
                   radius_z=.052,blend=.043),
    'brachioradialis':dict(center_x=.665,radius_x=.035,
                           radius_y=.102,radius_z=.033,blend=.039),
    'wrist':dict(center_x=.798,radius_x=.032,radius_z=.033,blend=.033),
    'palm':dict(center_x=.829,radius_x=.050,radius_y=.076,
                radius_z=.032,blend=.019),
    'gluteus_maximus':dict(center_x=.126,center_y=.949,center_z=-.081,
                           radius_x=.122,radius_y=.138,radius_z=.108,
                           blend=.036),
    'gluteus_medius':dict(center_x=.167,center_y=1.000,
                          radius_x=.098,radius_y=.090,radius_z=.081,
                          blend=.044),
    'thigh':dict(center_x=.168,radius_x=.113,radius_y=.290,
                 radius_z=.109,blend=.043),
    'rectus_femoris':dict(center_x=.174,center_z=.073,radius_x=.057,
                          radius_y=.212,radius_z=.057,blend=.040),
    'vastus_lateralis':dict(center_x=.219,center_z=.034,
                            radius_x=.055,radius_y=.211,radius_z=.058,
                            blend=.042),
    'vastus_medialis':dict(center_x=.114,center_y=.582,
                           radius_x=.055,radius_y=.139,radius_z=.057,
                           blend=.040),
    'adductor':dict(center_x=.115,radius_x=.060,
                    radius_y=.145,radius_z=.088,blend=.040),
    'hamstrings':dict(center_z=-.091,radius_x=.082,
                      radius_y=.220,radius_z=.068,blend=.042),
    'knee_patella':dict(center_y=.438,center_z=.040,
                        radius_x=.052,radius_y=.061,radius_z=.050,
                        blend=.040),
    'shin':dict(center_x=.171,radius_x=.064,radius_y=.201,
                radius_z=.069,blend=.041),
    'gastrocnemius_medial':dict(center_x=.131,center_y=.325,
                                radius_x=.049,radius_y=.125,
                                radius_z=.070,blend=.043),
    'gastrocnemius_lateral':dict(center_x=.207,center_y=.329,
                                 radius_x=.049,radius_y=.132,
                                 radius_z=.070,blend=.043),
    'tibialis_anterior':dict(radius_x=.049,radius_y=.156,
                             radius_z=.047,blend=.039),
    'ankle':dict(radius_x=.050,radius_y=.085,
                 radius_z=.051,blend=.034),
    'foot_heel':dict(radius_x=.073,radius_y=.054,
                     radius_z=.103,blend=.038),
    'foot_toes':dict(radius_x=.086,radius_y=.039,
                     radius_z=.139,blend=.037),
}

# Shallow existing incision network without the v10.3 exoskeleton effect.
TORSO_CUT_STRENGTH=.36
ARM_CUT_STRENGTH=.32


def shaped_aesthetic():
    old,_,_=shaped_arms()
    new=[];changed=[]
    for item in old:
        name=item.region
        side=0
        if name.startswith('left_'):side=-1;name=name[5:]
        elif name.startswith('right_'):side=1;name=name[6:]
        edits=AESTHETIC_OVERRIDES.get(name)
        if edits is None:new.append(item);continue
        edits=edits.copy()
        if side and 'center_x' in edits:edits['center_x']*=side
        if side and 'rotation_xy' in edits:edits['rotation_xy']*=side
        new.append(replace(item,**edits));changed.append(item.region)
    if len(new)!=106 or len({v.region for v in new})!=106:
        raise ValueError('Lost anatomical atlas region')
    for name in AESTHETIC_OVERRIDES:
        if not any(x.endswith(name) for x in changed):
            raise ValueError('Unused aesthetic region override '+name)
    return new,changed


def generate(pitch=.012):
    if not .009<=pitch<=.018:
        raise ValueError('QA authoring pitch is outside safe range')
    bounds=[(-1.03,1.03),(-.04,1.94),(-.48,.48)]
    shape=tuple(int(np.ceil((b-a)/pitch))+1 for a,b in bounds)
    field=np.ones(shape,dtype=np.float32)
    volumes,changed=shaped_aesthetic()
    axes=_composite(field,[np.asarray(x,dtype=np.float32) for x in bounds],
                    volumes,pitch)
    original=field.copy()
    torso=_surface_anatomy(field,axes)
    field[:]=original+TORSO_CUT_STRENGTH*(field-original)
    original=field.copy()
    arm=_arm_channels(field,axes)
    field[:]=original+ARM_CUT_STRENGTH*(field-original)
    field=gaussian_filter(field,sigma=.84)
    vertices,faces,_,_=marching_cubes(field,level=0,
        spacing=(pitch,)*3,allow_degenerate=False)
    vertices+=np.asarray([axis[0] for axis in axes])
    mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True)
    mesh.remove_unreferenced_vertices();mesh.fix_normals()
    if (not mesh.is_watertight or not mesh.is_winding_consistent
        or len(mesh.split(only_watertight=False))!=1):
        raise ValueError('Aesthetic sculpt must remain single closed body')
    if len(mesh.faces)<15000 or not .12<float(mesh.volume)<.35:
        raise ValueError('Invalid surface budget or human scale')
    return mesh,volumes,changed,torso,arm


def build(output,pitch=.012):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    mesh,anatomy,changed,torso,arm=generate(pitch)
    mesh.visual=trimesh.visual.TextureVisuals(
        material=trimesh.visual.material.PBRMaterial(
           name='STK_Master_V104_Neutral_Clay_Unapproved',
           baseColorFactor=[182,188,196,255],metallicFactor=0,
           roughnessFactor=.79,doubleSided=False))
    scene=trimesh.Scene();scene.add_geometry(mesh,
        geom_name='STK_V104_Athletic_LowerBody_Static_QA')
    raw=scene.export(file_type='glb')
    fn='stk_master_v104_aesthetic_lower_body_unapproved.glb'
    (output/fn).write_bytes(raw)
    stats={
        'schema':'stk_master_v104_athletic_proportion_and_lower_body_QA',
        'phase':'phase_1_block_4_lower_body_and_proportion',
        'parentVersion':103,'masterVersion':104,
        'designIntent':'Natural athletic proportions, less beast-like muscle bulk',
        'catalogCount':229,'catalogApproved':0,'catalogEnabled':0,
        'volumeCount':len(anatomy),'adjustedRegions':changed,
        'contourStrengthFraction':TORSO_CUT_STRENGTH,
        'armContourStrengthFraction':ARM_CUT_STRENGTH,
        'torsoLinesPreserved':len(torso),'armLinesPreserved':len(arm),
        'mesh':{'vertices':len(mesh.vertices),'triangles':len(mesh.faces),
                'watertight':bool(mesh.is_watertight),
                'windingConsistent':bool(mesh.is_winding_consistent),
                'components':len(mesh.split(only_watertight=False)),
                'volumeMetersCubed':round(float(mesh.volume),6),
                'pitchMeters':pitch,
                'boundsMeters':np.round(mesh.bounds,5).tolist()},
        'glb':{'filename':fn,'bytes':len(raw),
               'sha256':hashlib.sha256(raw).hexdigest()},
        'manualArtistApproved':False,'anatomyCertified':False,
        'productionReady':False,'rigged':False,'animated':False,
        'uvComplete':False,'reviewedOnPhysicalDevice':False,
        'approved':False,'enabled':False,
    }
    (output/'stk_master_v104_aesthetic_lower_body_report.json').write_text(
         json.dumps(stats,indent=2)+'\n',encoding='utf8')
    return mesh,stats


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--pitch',type=float,default=.012)
    args=p.parse_args()
    _,result=build(args.output,args.pitch)
    print(json.dumps({'schema':result['schema'],'mesh':result['mesh'],
                     'approved':False},indent=2))
