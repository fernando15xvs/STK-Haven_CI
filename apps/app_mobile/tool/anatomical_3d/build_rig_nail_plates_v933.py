#!/usr/bin/env python3
"""STK Haven v9.33: ten bone-attached nail PLATES with UV0. QA ONLY.

Closed 3D nail geometry added to the original disabled v9.32 GLB with an
independent PBR material and UVs. Nail nodes are children of the ten existing
distal bones; they inherit real animation without new motion tracks.
No professional cuticle, anatomical validation, continuous collision proof,
or production approval is implied.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path

from animate_hand_grip_v917 import DIGITS, SIDES
from audit_finger_contact_bounds_v923 import _read_refined
from retarget_cc0_glb import (
    EXERCISES, GLB, add, sub, mul, dot, norm, unit, cross, qrot, qconj,
)
from sculpt_finger_knuckles_v930 import _joint_axes
from sculpt_palm_thenar_v924 import _reference
from exercise_surface_collision_v911 import _samplers, _sample
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

GRID_U = 7
GRID_V = 5
MATERIAL_NAME = 'STK_NAIL_KERATIN_QA'
PREFIX = 'STK_NAIL_PLATE_'
PLATE_COUNT = 10


def append_uv(glb, points):
    if (not points or any(len(p)!=2 or not all(
            math.isfinite(x) and 0<=x<=1 for x in p) for p in points)):
        raise ValueError('Unsafe UV0 values')
    while len(glb.binary)%4:
        glb.binary.append(0)
    offset=len(glb.binary)
    glb.binary.extend(struct.pack(
        '<'+str(len(points)*2)+'f',
        *(x for row in points for x in row)))
    view_id=len(glb.doc['bufferViews'])
    glb.doc['bufferViews'].append({
        'buffer':0,'byteOffset':offset,'byteLength':len(points)*8,
        'target':34962,
    })
    accessor_id=len(glb.doc['accessors'])
    glb.doc['accessors'].append({
        'bufferView':view_id,'componentType':5126,
        'count':len(points),'type':'VEC2',
        'min':[0.,0.],'max':[1.,1.],
    })
    return accessor_id


def plate_geometry(glb,positions,joints,weights,skin,side,digit):
    bones,locations,axis=_joint_axes(glb,side,digit,skin)
    bone=bones[2]
    centre_bone=locations[2]
    span=norm(sub(locations[2],locations[1]))
    palm_normal=_reference(glb,side,skin)['normal']
    dorsal_axis=sub(palm_normal,mul(axis,dot(palm_normal,axis)))
    if norm(dorsal_axis)<.05 or not .003<span<.14:
        raise ValueError('Unsupported distal phalanx reference')
    dorsal=unit(dorsal_axis)
    lateral=unit(cross(axis,dorsal))
    palette=skin.index(bone)
    near=[]
    for i,p in enumerate(positions):
        weight=sum(float(w) for j,w in zip(joints[i],weights[i])
                   if int(j)==palette)
        if weight<.20:
            continue
        delta=sub(p,centre_bone)
        axial=dot(delta,axis)
        across=dot(delta,lateral)
        height=dot(delta,dorsal)
        if abs(axial-span*.36)<max(.012,span*.8) and abs(across)<.025:
            near.append((across,height))
    if len(near)<6:
        raise ValueError('No genuine distal skin vertices: '+digit+'_'+side)
    dorsal_height=max(h for _,h in near)
    if not math.isfinite(dorsal_height) or abs(dorsal_height)>.04:
        raise ValueError('Unusable skin dorsum')
    width=max(x for x,_ in near)-min(x for x,_ in near)
    hw=max(.003,min(.008,width*.32))
    hl=max(.0035,min(.010,span*.38))
    anchor=add(centre_bone,add(mul(axis,span*.36),
          mul(dorsal,dorsal_height+.00045)))
    inv=qconj(glb.restrot[bone])
    pts=[]
    normals=[]
    uv=[]
    for underside in (False,True):
        for row in range(GRID_V):
            v=-1+2*row/(GRID_V-1)
            for col in range(GRID_U):
                u=-1+2*col/(GRID_U-1)
                world=add(anchor,add(
                    mul(lateral,hw*u*(1-.20*abs(v)**4)),
                    add(mul(axis,hl*v),
                        mul(dorsal,
                            .00012*(1-u*u)*(1-v*v)-
                            (.00024 if underside else 0.)))))
                pts.append(qrot(inv,sub(world,centre_bone)))
                normals.append(qrot(inv,mul(dorsal,-1 if underside else 1)))
                uv.append(((u+1)/2,(v+1)/2))
    surface=GRID_U*GRID_V
    triangles=[]
    for row in range(GRID_V-1):
        for col in range(GRID_U-1):
            a=row*GRID_U+col
            c=a+GRID_U
            triangles.extend((a,a+1,c,a+1,c+1,c))
            triangles.extend((surface+a,surface+c,surface+a+1,
                              surface+a+1,surface+c,surface+c+1))
    border=list(range(GRID_U))
    border.extend(row*GRID_U+GRID_U-1 for row in range(1,GRID_V))
    border.extend((GRID_V-1)*GRID_U+col
                  for col in range(GRID_U-2,-1,-1))
    border.extend(row*GRID_U for row in range(GRID_V-2,0,-1))
    for k,a in enumerate(border):
        c=border[(k+1)%len(border)]
        triangles.extend((a,surface+a,c,c,surface+a,surface+c))
    if (len(pts)!=70 or len(triangles)//3!=136 or
        any(norm(p)>.04 for p in pts) or
        any(not all(math.isfinite(x) for x in p) for p in pts)):
        raise ValueError('Unsafe closed nail prototype')
    return bone,pts,normals,uv,triangles,{
        'side':side,'digit':digit,'realSkinSamples':len(near),
        'dorsalHeightMeters':round(dorsal_height,8),
        'halfWidthMeters':round(hw,8),
        'halfLengthMeters':round(hl,8),
        'vertices':len(pts),'triangles':len(triangles)//3,
        'independentUV0':True,'closedPlate':True,
    }


def build_one(raw,exercise):
    glb,p,j,w,morph,ibm,skin,_=_read_refined(raw,exercise)
    doc=glb.doc
    metadata=doc['extras']
    if (metadata.get('distalNailBedVersion')!=932 or
        metadata.get('fingerFoldSculptVersion')!=931 or
        metadata.get('nailPlatePrototypeVersion') is not None or
        metadata.get('approved') is not False or
        metadata.get('enabled') is not False or len(morph)!=8):
        raise ValueError('Require disabled original v9.32 mobile pilot')
    base={key:copy.deepcopy(doc[key]) for key in
          ('skins','animations','meshes','materials','nodes')}
    old_meshes=len(doc['meshes'])
    if old_meshes!=(3 if exercise=='ex_bench_press' else 2):
        raise ValueError('Unexpected original gym equipment meshes')
    doc['materials'].append({
        'name':MATERIAL_NAME,
        'pbrMetallicRoughness':{
            'baseColorFactor':[.79,.64,.59,1.],
            'metallicFactor':0.,'roughnessFactor':.51,
        },
        'doubleSided':True,
        'extras':{'candidateOnly':True,'expertReviewed':False},
    })
    mat=len(doc['materials'])-1
    records=[]
    for side in SIDES:
        for digit in DIGITS:
            bone,verts,normals,uv,indices,details=plate_geometry(
                glb,p,j,w,skin,side,digit)
            position=glb.append(verts,3,'POSITION',target=34962)
            normal=glb.append(normals,3,'NORMAL',target=34962)
            tex=append_uv(glb,uv)
            index=glb.append(
                [(i,) for i in indices],1,'INDICES',
                component=5123,target=34963)
            doc['accessors'][position]['min']=[
                min(v[k] for v in verts) for k in range(3)]
            doc['accessors'][position]['max']=[
                max(v[k] for v in verts) for k in range(3)]
            name=PREFIX+digit+'_'+side
            mesh_index=len(doc['meshes'])
            doc['meshes'].append({
                'name':name,'primitives':[{
                    'attributes':{'POSITION':position,'NORMAL':normal,
                                  'TEXCOORD_0':tex},
                    'indices':index,'material':mat,'mode':4,
                }],
                'extras':{'experimentalNailPlate':True},
            })
            node_index=len(doc['nodes'])
            doc['nodes'].append({
                'name':name,'mesh':mesh_index,
                'translation':[0.,0.,0.],
                'rotation':[0.,0.,0.,1.],
                'extras':{'approved':False,'enabled':False},
            })
            doc['nodes'][bone].setdefault('children',[]).append(node_index)
            records.append({**details,'bone':bone,'node':node_index,
                            'mesh':mesh_index})
    if len(records)!=PLATE_COUNT or len(doc['nodes'])>128:
        raise ValueError('Invalid ten-plate node budget')
    if (doc['skins']!=base['skins'] or
        doc['animations']!=base['animations'] or
        doc['meshes'][:old_meshes]!=base['meshes'] or
        doc['materials'][:-1]!=base['materials']):
        raise ValueError('Body mesh, rig or animation was altered')
    new_children={item['bone']:item['node'] for item in records}
    if len(new_children)!=10:
        raise ValueError('Two nail plates share one distal parent')
    for idx,prior in enumerate(base['nodes']):
        edited=copy.deepcopy(doc['nodes'][idx])
        if idx in new_children:
            if edited.get('children',[])[-1]!=new_children[idx]:
                raise ValueError('Invalid nail parent binding')
            edited['children'].pop()
            if not edited['children']:
                del edited['children']
        if edited!=prior:
            raise ValueError('Original skeletal node changed')
    metadata.update({
        'nailPlatePrototypeVersion':933,
        'sourceNailBedSha256':hashlib.sha256(raw).hexdigest(),
        'nailPlateMeshCount':10,
        'nailPlateUVCount':10,
        'nailPlateProfessionalAnatomyComplete':False,
        'dorsalOrientationExpertReviewed':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Prototype exceeds 1400 KiB GLB budget')
    check=GLB(output,expected_sha=None)
    tracks=_samplers(check)
    for seconds in (0.,1.,2.,3.,4.):
        world,_,_=_sample(check,tracks,seconds)
        for item in records:
            if math.dist(world[item['bone']],world[item['node']])>1e-8:
                raise ValueError('Nail plate failed animated bone parent')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'rigJoints':55,'morphTargets':8,
        'nailPlateNodes':10,'nailUVSets':10,
        'nailTriangles':sum(p['triangles'] for p in records),
        'animationPreserved':True,
        'phalanxAttachmentsVerified':True,
        'prototypeMaterial':MATERIAL_NAME,
        'plates':records,
        'expertHandAnatomyApproved':False,
        'collisionFreeCertified':False,
        'deviceVerified':False,
        'bytes':len(output),'approved':False,'enabled':False,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source/(exercise+'_v932_nail_bed_mobile_qa.glb')).read_bytes()
        model,report=build_one(raw,exercise)
        (output/(exercise+'_v933_rig_nail_plates_mobile_qa.glb')
         ).write_bytes(model)
        reports.append(report)
    result={
        'schema':'stk_v933_ten_uv_rig_nail_plates_qa',
        'catalogCount':229,'pilotCount':3,
        'rigJoints':55,'nailPlatesPerPilot':10,
        'allOriginalAnimationsPreserved':True,
        'professionalNailAnatomyComplete':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output/'nail_plates_v933_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    summary=build(args.input,args.output)
    print(json.dumps({
        'schema':summary['schema'],'pilots':summary['pilotCount'],
        'approved':False,'enabled':False},indent=2))
