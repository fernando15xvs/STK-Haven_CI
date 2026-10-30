#!/usr/bin/env python3
"""Reusable STK Haven anatomical master surface v2; authoring, NOT production.

From the archived CC0 55-joint neutral rig: weld split UV seams, blur existing
rough muscle-region masks, add subtle muscle relief, recalculate normals,
and create eight LEFT/RIGHT glTF corrective morph-target authoring channels.
This is NOT an anatomist-approved sculpt or a motion retargeter.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import struct
from retarget_cc0_glb import GLB

RELIEF_METERS={
 'pectoralis_major':.0090,'anterior_deltoid':.0068,
 'posterior_deltoid':.0068,'triceps_brachii':.0048,
 'latissimus_dorsi':.0068,'rhomboids':.0036,
 'middle_trapezius':.0040,'quadriceps_femoris':.0075,
 'gluteus_maximus':.0085,'hamstrings':.0060,'adductor_magnus':.0040
}
CORRECTIVE_SPEC={
 'scapular_elevation':('upperarm',.22,.0038),
 'elbow_flexion':('lowerarm',.13,.0034),
 'hip_flexion':('thigh',.22,.0048),
 'knee_flexion':('calf',.145,.0042)
}
SOURCE_SHA='7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749'

def length3(v):
    return math.sqrt(sum(c*c for c in v))

def normalized(v):
    length=length3(v)
    return tuple(c/length for c in v) if length>1e-12 else (0.,1.,0.)

def mul(v,s):
    return tuple(c*s for c in v)

def sub(a,b):
    return tuple(x-y for x,y in zip(a,b))

def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])

def source_arrays(glb):
    mesh=glb.doc['meshes'][0]
    parts=mesh['primitives']
    if len(parts)!=12:
        raise ValueError('Expected 11 muscle regions and neutral body')
    attrs=parts[0]['attributes']
    for primitive in parts:
        if primitive['attributes']!=attrs or 'stkMuscleRegion' not in primitive.get('extras',{}):
            raise ValueError('Expected shared skin attributes on all muscle regions')
    names=[p['extras']['stkMuscleRegion'] for p in parts]
    if set(names)!={'body'}|set(RELIEF_METERS):
        raise ValueError('Muscle region names missing or duplicated')
    positions=glb.accessor(attrs['POSITION'])
    normals=glb.accessor(attrs['NORMAL'])
    joints=glb.accessor(attrs['JOINTS_0'])
    weights=glb.accessor(attrs['WEIGHTS_0'])
    if not (len(positions)==len(normals)==len(joints)==len(weights)==70985):
        raise ValueError('Source CC0 vertex count differs from verified baseline')
    faces={p['extras']['stkMuscleRegion']:
       [int(value[0]) for value in glb.accessor(p['indices'])]
       for p in parts}
    if sum(len(v) for v in faces.values())!=107024*3:
        raise ValueError('Master source topology not preserved')
    return attrs,positions,normals,joints,weights,faces

def welded_masks(positions,normals,faces):
    key_to_weld={}
    vid_to_weld=[]
    averaged_normals=[]
    adjacency=[]
    votes=[]
    for index,position in enumerate(positions):
        key=tuple(round(c,5) for c in position)
        w=key_to_weld.get(key)
        if w is None:
            w=len(adjacency)
            key_to_weld[key]=w
            adjacency.append(set())
            averaged_normals.append([0.,0.,0.])
            votes.append(Counter())
        vid_to_weld.append(w)
        for k in range(3):averaged_normals[w][k]+=normals[index][k]
    averaged_normals=[normalized(n) for n in averaged_normals]
    for region,triangles in faces.items():
        for start in range(0,len(triangles),3):
            a,b,c=(vid_to_weld[triangles[start+k]] for k in range(3))
            for node in (a,b,c):votes[node][region]+=1
            for x,y in ((a,b),(b,c),(c,a)):
                if x!=y:adjacency[x].add(y);adjacency[y].add(x)
    masks=[]
    for region in RELIEF_METERS:
        strength=[vote.get(region,0)/max(1,sum(vote.values())) for vote in votes]
        for _ in range(3):
            strength=[.72*val+.28*sum(strength[j] for j in adjacency[i])/
                len(adjacency[i]) if adjacency[i] else val
                for i,val in enumerate(strength)]
        masks.append(strength)
    return vid_to_weld,averaged_normals,masks

def surface_relief(positions,normals,faces):
    weld,normals_weld,masks=welded_masks(positions,normals,faces)
    displaced=[]
    for i,point in enumerate(positions):
        wi=weld[i]
        amplitude=0.
        for (_,limit),strength in zip(RELIEF_METERS.items(),masks):
            t=max(0.,min(1.,(strength[wi]-.12)/.68))
            amplitude+=limit*t*t*(3.-2.*t)
        amplitude=min(amplitude,.0105)
        displaced.append(tuple(point[k]+normals_weld[wi][k]*amplitude
                               for k in range(3)))
    return displaced

def recompute_normals(original,positions,faces):
    acc=[[0.,0.,0.] for _ in positions]
    for triangles in faces.values():
        for start in range(0,len(triangles),3):
            a,b,c=triangles[start:start+3]
            n=cross(sub(positions[b],positions[a]),sub(positions[c],positions[a]))
            for idx in (a,b,c):
                for axis in range(3):acc[idx][axis]+=n[axis]
    output=[]
    for old,vector in zip(original,acc):
        normal=normalized(vector)
        if sum(x*y for x,y in zip(old,normal))<0:normal=mul(normal,-1)
        output.append(normalized(tuple(old[k]*.30+normal[k]*.70 for k in range(3))))
    return output

def replace_vec3_accessor(glb,index,values):
    a=glb.doc['accessors'][index]
    view=glb.doc['bufferViews'][a['bufferView']]
    if (a['type']!='VEC3' or a['componentType']!=5126 or
        a['count']!=len(values) or 'byteStride' in view):
        raise ValueError('Unsupported source POSITION/NORMAL accessor layout')
    offset=view.get('byteOffset',0)+a.get('byteOffset',0)
    flat=[x for p in values for x in p]
    struct.pack_into('<'+str(len(flat))+'f',glb.binary,offset,*flat)
    a['min']=[min(p[i] for p in values) for i in range(3)]
    a['max']=[max(p[i] for p in values) for i in range(3)]

def corrective_morph_targets(glb,points,normals,joints,weights):
    joints_by_name={glb.nodes[node]['name']:slot
                    for slot,node in enumerate(glb.doc['skins'][0]['joints'])}
    names=[]
    targets=[]
    audit={}
    for kind,(bone,radius,magnitude) in CORRECTIVE_SPEC.items():
        for side in ('l','r'):
            name=kind+'_'+side
            joint_name=bone+'_'+side
            center=glb.restpos[glb.by_name[joint_name]]
            influenced={joints_by_name[joint_name]}
            morph=[]
            extremes=[]
            for vertex,normal,ids,skin_weights in zip(points,normals,joints,weights):
                distance=math.dist(vertex,center)
                skin=sum(w for j,w in zip(ids,skin_weights) if int(j) in influenced)
                side_x=vertex[0] if side=='l' else -vertex[0]
                # Independent unilateral deformations with soft centerline taper.
                side_fade=max(0.,min(1.,side_x/.018))
                weight=min(1.,skin)*side_fade*math.exp(-.5*(distance/radius)**2)
                delta=mul(normal,magnitude*weight)
                morph.append(delta)
                extremes.append(length3(delta))
            index=glb.append(morph,3,'VEC3',target=34962)
            targets.append({'POSITION':index})
            names.append(name)
            audit[name]={'maxDeltaMeters':round(max(extremes),7),
                         'magnitudeLimitMeters':magnitude,
                         'driverConnected':False,'expertApproved':False}
    mesh=glb.doc['meshes'][0]
    for p in mesh['primitives']:
        p['targets']=list(targets)
    mesh['weights']=[0.]*len(targets)
    mesh.setdefault('extras',{})['targetNames']=names
    mesh['extras']['morphTargetsStatus']='authoring_only_not_animated'
    return audit

def build_surface_v2(data):
    source_master_sha=hashlib.sha256(data).hexdigest()
    glb=GLB(data,expected_sha=None)
    extras=glb.doc.get('extras',{})
    if (extras.get('assetId')!='stk_haven_cc0_humanoid_master_55' or
        extras.get('sourceSha256')!=SOURCE_SHA or
        extras.get('approved') is not False or
        extras.get('enabled') is not False or
        len(glb.doc['skins'][0]['joints'])!=55 or glb.doc.get('animations')):
        raise ValueError('Expected unapproved neutral 55-joint master, no animations')
    attrs,points,normals,joints,weights,faces=source_arrays(glb)
    sculpted=surface_relief(points,normals,faces)
    recalculated=recompute_normals(normals,sculpted,faces)
    shift=[math.dist(a,b) for a,b in zip(points,sculpted)]
    moved=sum(s>.0002 for s in shift)
    if moved<3000 or max(shift)>.011:
        raise ValueError('Surface relief exceeds strictly limited sculpt envelope')
    replace_vec3_accessor(glb,attrs['POSITION'],sculpted)
    replace_vec3_accessor(glb,attrs['NORMAL'],recalculated)
    morphs=corrective_morph_targets(glb,sculpted,recalculated,joints,weights)
    glb.doc['meshes'][0]['name']='STK_MASTER_SURFACE_RELIEF_V2_REVIEW'
    glb.doc['meshes'][0].setdefault('extras',{})[
        'surfaceRelief']='continuous_weighted_region_relief'
    glb.doc['extras']=dict(extras,surfaceVersion=2,
        sourceMasterSha256=source_master_sha,approved=False,enabled=False,
        status='procedural_relief_morph_correctives_authoring_only')
    output=glb.bytes()
    report={'surfaceVersion':2,'sourceAssetId':extras['assetId'],
       'sourceMasterSha256':source_master_sha,'sourceLicense':'CC0-1.0',
       'sourceSha256':SOURCE_SHA,'jointCount':55,'vertexCount':len(points),
       'triangleCount':107024,'muscleRegions':list(RELIEF_METERS),
       'muscleReliefAmplitudeMeters':RELIEF_METERS,
       'movedVertexCount':moved,'maxReliefMeters':round(max(shift),7),
       'morphTargets':morphs,'morphWeightsDefaultZero':True,
       'productionReady':False,'expertApproved':False,
       'approved':False,'enabled':False,'catalogCount':229,
       'warnings':['Procedural muscle relief is not a professional anatomical sculpt',
          'Eight left/right joint morphs have no motion drivers and are off by default',
          'Requires anatomical and biomechanical expert review',
          'Flutter GPU rendering and physical-device QA still pending']}
    return output,report

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    raw,report=build_surface_v2(args.input.read_bytes())
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'stk_haven_master_surface_v2_unapproved.glb').write_bytes(raw)
    (args.output/'master_surface_v2_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'status':'unapproved_sculpt_foundation',
       'bytes':len(raw),'moved':report['movedVertexCount'],
       'maxReliefMeters':report['maxReliefMeters'],
       'morphTargets':len(report['morphTargets']),
       'approved':False,'enabled':False},indent=2))
if __name__=='__main__':
    main()
