#!/usr/bin/env python3
"""STK Haven v10.3, phase 1 block 3: new hands/arms on unapproved v10 master.

Authoring-only volumetric sculpt. Reworks proportions of biceps, triceps,
forearm and wrist and creates independently readable four digits + thumb.
Starts from v10.2 authoring *parameters*, not v9 exercise media.
Not a production-ready art asset, rig, motion or device-reviewed character.
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

from build_master_silhouette_v10 import AnatomyVolume, _composite
from sculpt_torso_back_v102 import shaped_volumes, _surface_anatomy, _incision

VERSION=103

# Rigging remains on hold: hand volumes are anatomically distinct silhouettes,
# but they are not yet retopologized or weighted for grips.
ARM_PARAMETERS={
    'deltoid_lateral':dict(center_x=.352,center_y=1.459,
        radius_x=.091,radius_y=.098,radius_z=.093,blend=.034),
    'deltoid_anterior':dict(center_x=.334,center_y=1.443,center_z=.061,
        radius_x=.068,radius_y=.087,radius_z=.072,blend=.032),
    'deltoid_posterior':dict(center_x=.342,center_y=1.444,center_z=-.073,
        radius_x=.071,radius_y=.089,radius_z=.071,blend=.032),
    'upper_arm':dict(center_x=.471,center_y=1.309,center_z=-.005,
        radius_x=.077,radius_y=.195,radius_z=.070,blend=.038),
    'biceps_brachii':dict(center_x=.465,center_y=1.309,center_z=.044,
        radius_x=.057,radius_y=.131,radius_z=.051,blend=.035),
    'triceps':dict(center_x=.473,center_y=1.312,center_z=-.059,
        radius_x=.064,radius_y=.151,radius_z=.047,blend=.035),
    'elbow':dict(center_x=.587,center_y=1.170,center_z=-.001,
        radius_x=.049,radius_y=.064,radius_z=.052,blend=.026),
    'forearm':dict(center_x=.693,center_y=1.059,center_z=.009,
        radius_x=.060,radius_y=.170,radius_z=.059,blend=.033),
    'brachioradialis':dict(center_x=.668,center_y=1.090,center_z=.054,
        radius_x=.041,radius_y=.105,radius_z=.035,blend=.030),
    'wrist':dict(center_x=.801,center_y=.920,center_z=.009,
        radius_x=.034,radius_y=.060,radius_z=.034,blend=.030),
    'palm':dict(center_x=.833,center_y=.850,center_z=.022,
        radius_x=.060,radius_y=.079,radius_z=.032,blend=.015),
    'thumb':dict(center_x=.775,center_y=.815,center_z=.060,
        radius_x=.023,radius_y=.057,radius_z=.026,blend=.014),
}

# digits in frontal +X side: distal phalanges 1..4 and an opposing thumb.
DIGIT_SPECS=(
    (.792,.737,.032,.0105,.063,.013), # index
    (.818,.729,.032,.0110,.072,.013), # middle
    (.846,.734,.030,.0105,.067,.012), # ring
    (.872,.752,.029,.0093,.049,.011), # pinky
)


def shaped_arms():
    torso,previous=shaped_volumes()
    result=[]
    corrected=[]
    for item in torso:
        prefix,_,suffix=item.region.partition('_')
        side=-1 if prefix=='left' else (1 if prefix=='right' else 0)
        if side and suffix in ARM_PARAMETERS:
            edits=dict(ARM_PARAMETERS[suffix])
            if 'center_x' in edits: edits['center_x']*=side
            if 'rotation_xy' in edits: edits['rotation_xy']*=side
            fixed=replace(item,**edits)
            corrected.append(fixed.region)
            result.append(fixed)
        elif side and suffix.startswith('finger_'):
            # Replace first generation's overlapping 4 fat fingers with
            # slender, unequal, visible fingertip lengths along palm width.
            index=int(suffix.split('_')[-1])
            x,y,z,rx,ry,rz=DIGIT_SPECS[index]
            result.append(replace(item,center_x=x*side,center_y=y,
                center_z=z,radius_x=rx,radius_y=ry,radius_z=rz,
                rotation_xy=side*.025,blend=.006))
            corrected.append(item.region)
        else:
            result.append(item)
    for side,sign in (('left',-1),('right',1)):
        # Distinct anatomical segments: thumb opposition, palm heel,
        # first metacarpals and four independent knuckle regions.
        result.append(AnatomyVolume(side+'_thenar_eminence',sign*.795,.843,
            .062,.031,.045,.034,rotation_xy=-sign*.2,blend=.015))
        result.append(AnatomyVolume(side+'_hypothenar',sign*.855,.857,
            -.003,.033,.051,.025,rotation_xy=sign*.23,blend=.018))
        result.append(AnatomyVolume(side+'_thumb_distal',sign*.747,.765,
            .080,.019,.042,.021,rotation_xy=-sign*.24,blend=.010))
        for index,(x,y,z,rx,ry,rz) in enumerate(DIGIT_SPECS):
            result.append(AnatomyVolume(side+f'_metacarpal_{index}',
                sign*x,.795,z,.014,.039,.015,
                rotation_xy=sign*.04,blend=.008))
    expected=92+2*(3+4)
    if len(result)!=expected or len(corrected)!=len(ARM_PARAMETERS)*2+8:
        raise ValueError('Unexpected anatomy region count/bilateral sculpt')
    if len({v.region for v in result})!=expected:
        raise ValueError('Duplicate anatomical volume IDs')
    return result,corrected,previous


def _arm_channels(field,axes):
    """Real but bounded grooves emphasizing proximal biceps/triceps + wrist.

    Applied to positive and negative X mirrored XY, front/back Z gated,
    excluding palms (where distinct solids alone describe fingers).
    """
    cuts=[]
    for sign,side in ((-1,'left'),(1,'right')):
        for name,p0,p1,depth,sigma,face in (
            ('biceps_tendon',(.497,1.220),(.564,1.179),.005,.010,'front'),
            ('biceps_deltoid',(.408,1.388),(.466,1.354),.005,.012,'front'),
            ('triceps_long_head',(.427,1.383),(.529,1.249),.006,.011,'back'),
            ('brachioradialis_border',(.643,1.108),(.760,.972),.004,.010,'front'),
        ):
            a=(sign*p0[0],p0[1]);b=(sign*p1[0],p1[1])
            # v10.2 anterior/posterior SDF incision gate targets torso;
            # upper arm has a much shallower z surface. Restrict the channel
            # with a narrower local Z-depth and only the intended limb shell.
            zlo,zhi=(.027,.120) if face=='front' else (-.130,-.027)
            sl=[]
            for axis,lo,hi in zip(axes,
                (min(a[0],b[0])-.038,min(a[1],b[1])-.038,zlo),
                (max(a[0],b[0])+.038,max(a[1],b[1])+.038,zhi)):
                sl.append(slice(max(0,int(np.searchsorted(axis,lo)-1)),
                                min(len(axis),int(np.searchsorted(axis,hi)+1))))
            xx=axes[0][sl[0]][:,None,None]
            yy=axes[1][sl[1]][None,:,None]
            zz=axes[2][sl[2]][None,None,:]
            dx=b[0]-a[0];dy=b[1]-a[1]
            t=np.clip(((xx-a[0])*dx+(yy-a[1])*dy)/(dx*dx+dy*dy),0,1)
            d=np.sqrt((xx-a[0]-dx*t)**2+(yy-a[1]-dy*t)**2)
            zgate=np.clip(((zz-.024) if face=='front' else (-.024-zz))/.045,0,1)
            field[tuple(sl)]+=depth*np.exp(-.5*(d/sigma)**2)*zgate
            cuts.append(side+'_'+name)
    return cuts


def generate(pitch=.012):
    if not .007<=pitch<=.018:
        raise ValueError('Unsafe v10.3 authoring resolution')
    bounds=[(-1.03,1.03),(-.04,1.94),(-.48,.48)]
    anatomy,changed,_=shaped_arms()
    shape=tuple(int(np.ceil((b-a)/pitch))+1 for a,b in bounds)
    field=np.ones(shape,dtype=np.float32)
    axes=_composite(field,[np.asarray(pair,dtype=np.float32) for pair in bounds],
                    anatomy,pitch)
    torso_lines=_surface_anatomy(field,axes)
    arm_lines=_arm_channels(field,axes)
    field=gaussian_filter(field,sigma=.62)
    points,faces,_,_=marching_cubes(field,level=0,
        spacing=(pitch,)*3,allow_degenerate=False)
    points+=np.asarray([a[0] for a in axes])
    mesh=trimesh.Trimesh(vertices=points,faces=faces,process=True)
    mesh.remove_unreferenced_vertices()
    mesh.fix_normals()
    if not mesh.is_watertight or not mesh.is_winding_consistent:
        raise ValueError('QA master must be watertight and consistently wound')
    if not .15<float(mesh.volume)<.35 or len(mesh.faces)<19000:
        raise ValueError('Invalid v10.3 anatomical body size or LOD')
    return mesh,anatomy,changed,torso_lines,arm_lines


def build(output:Path,pitch=.012):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    mesh,anatomy,changed,torso_lines,arm_lines=generate(pitch)
    mesh.visual=trimesh.visual.TextureVisuals(
        material=trimesh.visual.material.PBRMaterial(
          name='STK_Master_V103_Neutral_Clay_QA',
          baseColorFactor=[178,184,196,255],
          metallicFactor=0,roughnessFactor=.78,doubleSided=False))
    scene=trimesh.Scene()
    scene.add_geometry(mesh,geom_name='STK_V103_ArmsAndFingers_Static_QA')
    raw=scene.export(file_type='glb')
    name='stk_master_v103_arms_hands_unapproved.glb'
    (output/name).write_bytes(raw)
    report={
      'schema':'stk_v103_independent_master_bilateral_arms_and_hands_QA',
      'phase':'phase_1_block_3_arms_and_hands',
      'source':'v10.2 unapproved authoring parameters; no v9 exercise geometry',
      'parentVersion':102,'masterVersion':103,
      'torsoLinesPreserved':len(torso_lines),
      'armChannels':arm_lines,
      'anatomyRegions':len(anatomy),
      'regionsReshaped':changed,
      'realSeparateDigitVolumesPerHand':4,
      'opposableThumbSegmentsPerHand':2,
      'mesh':{
        'vertices':len(mesh.vertices),'triangles':len(mesh.faces),
        'watertight':bool(mesh.is_watertight),
        'windingConsistent':bool(mesh.is_winding_consistent),
        'boundsMeters':np.round(mesh.bounds,5).tolist(),
        'volumeMetersCubed':round(float(mesh.volume),6),
        'pitchMeters':pitch,
      },
      'glb':{'filename':name,'bytes':len(raw),
             'sha256':hashlib.sha256(raw).hexdigest()},
      'headAndFaceFinal':False,
      'manualCharacterArtistReviewed':False,
      'handGripTopologyFinished':False,
      'skinRigComplete':False,'UVComplete':False,'texturingComplete':False,
      'performanceOnPhysicalDevicesReviewed':False,
      'approved':False,'enabled':False,'productionReady':False,
      'catalogExercises':229,'catalogEnabled':0,
    }
    (output/'stk_master_v103_arms_hands_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return mesh,report


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--pitch',type=float,default=.012)
    a=p.parse_args()
    _,report=build(a.output,a.pitch)
    print(json.dumps({'schema':report['schema'],
       'faces':report['mesh']['triangles'],
       'modifiedRegions':len(report['regionsReshaped']),
       'approved':report['approved']}))