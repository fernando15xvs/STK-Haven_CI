#!/usr/bin/env python3
"""STK Haven 55-joint CC0 v8 muscle-silhouette pass (unapproved offline QA).

Sculpts eleven bilateral atlas regions on v7, retaining every bind pose,
skinning weight, 8 corrective morphs and the original seven animations.
Copies the same positions/normals to three v9.10 exercise-specific GLBs.
This is procedural volume art, NOT a professional anatomical mesh.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from retarget_cc0_glb import GLB
from build_master_surface_v6 import BUDGET_BYTES, replace_accessor, topology
from build_master_surface_v7 import (region_votes, weighted_profile,
                                      face_orientation, norm, smoothstep)
from build_master_surface_v2 import recompute_normals, sub

REGION_STRENGTH = {
    'pectoralis_major': .0038,
    'anterior_deltoid': .0028,
    'posterior_deltoid': .0028,
    'triceps_brachii': .0028,
    'latissimus_dorsi': .0036,
    'rhomboids': .0015,
    'middle_trapezius': .0016,
    'quadriceps_femoris': .0040,
    'gluteus_maximus': .0040,
    'hamstrings': .0030,
    'adductor_magnus': .0025,
}
MAX_ADDED_RELIEF = .0040
MIN_CHANGE = .00004
SIDE_GUARD = .015
BLEND_WIDTH = .035
REGION_ORDER = tuple(REGION_STRENGTH)
EXERCISE_IDS = ('ex_bench_press', 'ex_barbell_row', 'ex_squat')

def _smooth_votes(votes, graph):
    result={}
    for name, values in votes.items():
        mask=list(map(float, values))
        for _ in range(2):
            mask=[.72*mask[i]+.28*(sum(mask[j]*w for j,w in neighbors.items())/
                      sum(neighbors.values()) if neighbors else mask[i])
                  for i,neighbors in enumerate(graph)]
        result[name]=mask
    return result

def _bell(point, center, scale, muscle):
    """Individual anisotropic volume, not a biological fiber simulation."""
    r=sum(((point[k]-center[k])/scale[k])**2 for k in range(3))
    main=math.exp(-.75*r)
    if muscle=='quadriceps_femoris':
        x=(point[0]-center[0])/scale[0]
        main*=.82+.18*math.cos(2.2*x)**2
    elif muscle=='pectoralis_major':
        y=(point[1]-center[1])/scale[1]
        main*=.93+.07*math.exp(-1.2*(y+.35)**2)
    elif muscle=='latissimus_dorsi':
        y=(point[1]-center[1])/scale[1]
        main*=.88+.12*smoothstep((y+1.4)/2.8)
    elif muscle=='gluteus_maximus':
        y=(point[1]-center[1])/scale[1]
        main*=.89+.11*math.exp(-1.5*y*y)
    return main

def sculpt_volume(points,normals,votes,graph):
    if not len(points)==len(normals)==len(graph) or set(votes)!=set(REGION_ORDER):
        raise ValueError('v8 requires 11 atlas regions and shared skin topology')
    smoothed=_smooth_votes(votes,graph)
    profiles={(name,side):weighted_profile(points,votes[name],side)
              for name in REGION_ORDER for side in ('l','r')}
    output=[]
    biggest=0.
    region_hits={name:0 for name in REGION_ORDER}
    altered=0
    for i,(point,normal) in enumerate(zip(points,normals)):
        if abs(point[0])<=SIDE_GUARD:
            output.append(tuple(point));continue
        side='l' if point[0]>0 else 'r'
        amplitude=0.
        for name,limit in REGION_STRENGTH.items():
            center,scale=profiles[name,side]
            strength=smoothstep((smoothed[name][i]-.06)/.56)
            active=limit*_bell(point,center,scale,name)*strength
            if active>.00008:region_hits[name]+=1
            amplitude+=active
        lengths=[norm(sub(points[j],point)) for j in graph[i]
                 if norm(sub(points[j],point))>1e-5]
        cap=min(MAX_ADDED_RELIEF,.14*min(lengths) if lengths else 0.)
        amplitude=min(amplitude,cap)
        amplitude*=smoothstep((abs(point[0])-SIDE_GUARD)/BLEND_WIDTH)
        nlen=norm(normal)
        if not math.isfinite(amplitude) or not .7<nlen<1.3:
            raise ValueError('Unsafe surface normal or relief magnitude')
        shifted=tuple(point[k]+normal[k]/nlen*amplitude for k in range(3))
        output.append(shifted)
        amount=math.dist(point,shifted)
        biggest=max(biggest,amount)
        if amount>MIN_CHANGE:altered+=1
    if altered<200 or biggest>MAX_ADDED_RELIEF+1e-7:
        raise ValueError('Insufficient or unbounded v8 muscle relief')
    if any(count==0 for count in region_hits.values()):
        raise ValueError('Anatomical region missing sampled v8 changes')
    return output,{'editedVertices':altered,'maximumAddedMeters':round(biggest,7),
                   'regionAffectedVertices':region_hits,
                   'perRegionAmplitudeMeters':REGION_STRENGTH,
                   'proceduralOnly':True}

def _check_base(glb,exercise=None):
    doc=glb.doc;meta=doc.get('extras',{})
    if (meta.get('masterSculptDetailVersion')!=7 or
        meta.get('sourceSha256')!='7135e03b6259e970458deff3e0458610914d7c35164cae12611101361e4a5749' or
        meta.get('approved') is not False or meta.get('enabled') is not False or
        len(doc.get('skins',[]))!=1 or
        len(doc['skins'][0]['joints'])!=55 or
        len(doc.get('meshes',[]))!=(1 if exercise is None else (3 if exercise=='ex_bench_press' else 2)) or
        len(doc['meshes'][0]['primitives'])!=12 or
        len(doc.get('animations',[]))!=(7 if exercise is None else 1)):
        raise ValueError('Require trusted unapproved v7 master or v9.10 exercise')
    if exercise is not None and (exercise not in EXERCISE_IDS or
        meta.get('exerciseId')!=exercise or
        meta.get('masterExercisePilotVersion')!=910):
        raise ValueError('Exercise pilot provenance mismatch')
    primitives=doc['meshes'][0]['primitives']
    attrs=primitives[0]['attributes']
    if any(p['attributes']!=attrs or
           p['targets']!=primitives[0]['targets'] for p in primitives):
        raise ValueError('v8 cannot alter disjoint streams')
    return attrs

def _replace_skin_surface(glb,points,normals):
    attrs=_check_base(glb,glb.doc.get('extras',{}).get('exerciseId'))
    replace_accessor(glb,attrs['POSITION'],points)
    replace_accessor(glb,attrs['NORMAL'],normals)
    ac=glb.doc['accessors'][attrs['POSITION']]
    ac['min']=[min(p[i] for p in points) for i in range(3)]
    ac['max']=[max(p[i] for p in points) for i in range(3)]
    glb.doc['extras']=dict(glb.doc['extras'],masterSculptDetailVersion=8,
        anatomyArtVersion=913,approved=False,enabled=False,
        detailStatus='unapproved_procedural_anatomical_silhouette_qa')
    return glb.bytes()

def build(master_bytes,pilot_bytes):
    master=GLB(master_bytes,expected_sha=None)
    attrs=_check_base(master)
    positions=master.accessor(attrs['POSITION'])
    normals=master.accessor(attrs['NORMAL'])
    weights=master.accessor(attrs['WEIGHTS_0'])
    joints=master.accessor(attrs['JOINTS_0'])
    votes,faces=region_votes(master,len(positions))
    graph=topology(master,positions,joints,weights)
    refined,metrics=sculpt_volume(positions,normals,votes,graph)
    face_count=face_orientation(positions,refined,faces)
    corrected=recompute_normals(normals,refined,faces)
    if any(abs(norm(v)-1.)>.002 for v in corrected):
        raise ValueError('Unnormalized v8 sculpt surface')
    result={'version':913,'sourceVersion':7,'jointCount':55,
        'morphTargetCount':8,'atlasRegions':11,'clips':7,
        'samplesSculpted':len(refined),'triangles':face_count,
        'catalogCount':229,'approved':False,'enabled':False,
        'professionallyAnatomical':False,'deviceGpuVerified':False,
        'sculpt':metrics,'files':{}}
    new_master=_replace_skin_surface(master,refined,corrected)
    if len(new_master)>BUDGET_BYTES:
        raise ValueError('v8 master mobile 850 KiB budget exceeded')
    result['files']['master']={'bytes':len(new_master),
        'sha256':hashlib.sha256(new_master).hexdigest()}
    variants={}
    for exercise in EXERCISE_IDS:
        pilot=GLB(pilot_bytes[exercise],expected_sha=None)
        pattrs=_check_base(pilot,exercise)
        before=pilot.accessor(pattrs['POSITION'])
        if len(before)!=len(positions) or any(
                math.dist(a,b)>1e-6 for a,b in zip(before,positions)):
            raise ValueError('Pilot neutral anatomy does not match master')
        candidate=_replace_skin_surface(pilot,refined,corrected)
        if len(candidate)>1400*1024:
            raise ValueError('Exercise review GLB size exceeded')
        variants[exercise]=candidate
        result['files'][exercise]={'bytes':len(candidate),
            'sha256':hashlib.sha256(candidate).hexdigest()}
    return new_master,variants,result

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--master',type=Path,required=True)
    parser.add_argument('--pilots',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    ins={ex:(args.pilots/(ex+'_master55_v910_scapular_qa.glb')).read_bytes()
         for ex in EXERCISE_IDS}
    master,variants,report=build(args.master.read_bytes(),ins)
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'stk_master_v8_anatomy_preview.glb').write_bytes(master)
    for ex,data in variants.items():
        (args.output/(ex+'_master55_v8_sculpt_qa.glb')).write_bytes(data)
    (args.output/'master_anatomy_v913_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'version':report['version'],
                      'regions':report['atlasRegions'],
                      'changed':report['sculpt']['editedVertices'],
                      'approved':False,'enabled':False},indent=2))

if __name__=='__main__':main()
