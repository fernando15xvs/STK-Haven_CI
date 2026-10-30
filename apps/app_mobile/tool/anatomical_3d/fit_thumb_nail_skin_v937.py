#!/usr/bin/env python3
"""STK Haven v9.37: 3D skin-based thumb nail fitting, QA only.

Correct the v9.34 12-15mm thumb gap by searching true bone-local 3D nail
translations, bounded to 12mm. Use actual morphed, skinned distal triangles;
retain changes only if independent 241-pose 60Hz risk audit improves without
worsening sampled embed/detach. No continuous collision or artist certification.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import SIDES
from audit_finger_contact_bounds_v923 import _read_refined
from build_rig_nail_plates_v933 import PREFIX,MATERIAL_NAME
from nail_plate_skin_proximity_v934 import (
    closest_triangle,MAX_FACES_PER_FINGER,
    POSSIBLE_EMBED_DEPTH,MAX_SAMPLE_DISTANCE,
)
from exercise_surface_collision_v911 import _samplers,_sample,_skin_vertex
from retarget_cc0_glb import (
    GLB,EXERCISES,add,sub,mul,dot,norm,unit,cross,qrot,qconj,
)
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

FPS=60
FRAMES=241
MAX_MOVE=.012
MAX_DISTANCE_REGRESSION=.00065
COARSE=(0,30,60,90,120,150,180,210,240)
THUMBS=tuple('thumb_'+s for s in SIDES)
PROBES=tuple(15+row*5+col for row in range(3) for col in (0,2,4))


def gate(before,after):
    fields=('embedded','detached','maxDistance')
    if any(key not in x or not math.isfinite(x[key])
           or x[key]<0 for x in (before,after) for key in fields):
        raise ValueError('Incomplete or invalid sampled proximity evidence')
    if after['embedded']>before['embedded']:
        return False,'more_possible_penetrations'
    if after['detached']>before['detached']:
        return False,'more_possible_detachment'
    if after['maxDistance']>before['maxDistance']+MAX_DISTANCE_REGRESSION:
        return False,'worse_maximum_gap'
    if (after['embedded']==before['embedded'] and
        after['detached']==before['detached']):
        return False,'no_measured_improvement'
    return True,'sampled_risk_reduced'


def _skin(glb,exercise,raw):
    g,points,joints,weights,morphs,ibm,skin,groups=(
        _read_refined(raw,exercise))
    extra=g.doc['extras']
    if (extra.get('nailLodPrototypeVersion')!=936 or
        extra.get('nailContactOffsetOptimizerVersion')!=935 or
        extra.get('thumbNail3dFitVersion') is not None or
        extra.get('approved') is not False or
        extra.get('enabled') is not False):
        raise ValueError('Require disabled original v9.36 LOD nail pilot')
    tracks=_samplers(g)
    world,rot,activation=_sample(g,tracks,0.)
    entries={}
    for label in THUMBS:
        node=g.by_name.get(PREFIX+label)
        parent=g.by_name.get(label.replace('thumb_','thumb_03_'))
        if node is None or parent is None or g.parents.get(node)!=parent:
            raise ValueError('Missing real distal thumb parent')
        plate=g.doc['nodes'][node]
        if plate.get('translation')!=[0.,0.,0.] or (
            plate.get('rotation')!=[0.,0.,0.,1.]):
            raise ValueError('Nail plate no longer in baseline rigid pose')
        p=g.doc['meshes'][plate['mesh']]['primitives'][0]
        if g.doc['materials'][p['material']]['name']!=MATERIAL_NAME:
            raise ValueError('Unsafe nail material')
        at=p['attributes']
        if set(at)!={'POSITION','NORMAL','TEXCOORD_0'}:
            raise ValueError('Incomplete actual nail UV0')
        vertex=g.accessor(at['POSITION'])
        uv=g.accessor(at['TEXCOORD_0'])
        idx=g.accessor(p['indices'])
        if (len(vertex)!=30 or len(uv)!=30 or len(idx)!=168 or
            any(not 0<=x<=1 for row in uv for x in row)):
            raise ValueError('Invalid rigid 30-vertex nail plate')
        entry={'node':node,'probes':[vertex[i] for i in PROBES]}
        # Pick closest REAL distal-skin triangles after morph+skin at t=0.
        skin_at_zero={}
        for triangle in groups[label]:
            for i in triangle:
                if i not in skin_at_zero:
                    skin_at_zero[i]=_skin_vertex(
                        points[i],[shape[i] for shape in morphs],
                        weights[i],joints[i],ibm,world,rot,skin,activation)
        first=mul(tuple(sum(
            add(world[node],qrot(rot[node],p))[k] for p in entry['probes'])
            for k in range(3)),1/9)
        ranked=[]
        for triangle in groups[label]:
            centre=mul(add(add(skin_at_zero[triangle[0]],
                               skin_at_zero[triangle[1]]),
                           skin_at_zero[triangle[2]]),1/3)
            ranked.append((norm(sub(centre,first)),triangle))
        ranked.sort(key=lambda x:x[0])
        entry['faces']=[face for _,face in ranked[:MAX_FACES_PER_FINGER]]
        if len(entry['faces'])<3:
            raise ValueError('No nearby animated distal-skin triangles')
        entry['vertices']={i for face in entry['faces'] for i in face}
        entries[label]=entry
    samples={}
    for entry in entries.values():
        for i in entry['vertices']:
            samples[i]=(points[i],[shape[i] for shape in morphs],
                        weights[i],joints[i])
    return g,tracks,ibm,skin,entries,samples


def _posed(samples,ibm,skin,world,rot,morph):
    return {i:_skin_vertex(p,d,w,j,ibm,world,rot,skin,morph)
            for i,(p,d,w,j) in samples.items()}


def _facepoints(entry,posed):
    faces=[]
    for a,b,c in entry['faces']:
        pa,pb,pc=posed[a],posed[b],posed[c]
        normal=cross(sub(pb,pa),sub(pc,pa))
        if norm(normal)<1e-11:
            raise ValueError('Degenerate skinned thumb skin surface')
        faces.append((pa,pb,pc,unit(normal)))
    return faces


def _probe(entry,translation,world,rot,faces,offsets=False):
    origin=world[entry['node']]
    orientation=rot[entry['node']]
    embeds=detaches=0
    maximum=0.
    vectors=[]
    for local in entry['probes']:
        point=add(origin,qrot(orientation,add(local,translation)))
        best_distance=float('inf')
        best_sign=0.
        nearest=None
        for a,b,c,normal in faces:
            close=closest_triangle(point,a,b,c)
            difference=sub(point,close)
            distance=norm(difference)
            if distance<best_distance:
                best_distance=distance
                best_sign=dot(difference,normal)
                nearest=close
        if nearest is None or not math.isfinite(best_distance):
            raise ValueError('Invalid nail-to-skin proximity')
        embeds+=int(best_sign<-POSSIBLE_EMBED_DEPTH and
                    best_distance<MAX_SAMPLE_DISTANCE)
        detaches+=int(best_distance>MAX_SAMPLE_DISTANCE)
        maximum=max(maximum,best_distance)
        if offsets:
            vectors.append(qrot(qconj(orientation),sub(nearest,point)))
    return embeds,detaches,maximum,vectors


def _audit(g,tracks,ibm,skin,entries,samples,frames,offsets):
    status={name:{
        'embedded':0,'detached':0,'maxDistance':0.,
        'frames':len(frames),'probes':len(frames)*9,
        'triangles':len(item['faces']),
    } for name,item in entries.items()}
    for frame in frames:
        world,rot,morph=_sample(g,tracks,frame/FPS)
        skin_pos=_posed(samples,ibm,skin,world,rot,morph)
        for name,entry in entries.items():
            a,b,c,_=_probe(entry,offsets.get(name,(0.,0.,0.)),world,rot,
                          _facepoints(entry,skin_pos))
            row=status[name]
            row['embedded']+=a
            row['detached']+=b
            row['maxDistance']=max(row['maxDistance'],c)
    for row in status.values():
        row['maxDistance']=round(row['maxDistance'],8)
    return status


def fit(raw,exercise):
    if exercise not in EXERCISES or len(raw)>MAX_MOBILE_BYTES:
        raise ValueError('Unsafe exercise or GLB size')
    g,tracks,ibm,skin,entries,samples=_skin(None,exercise,raw)
    originals={key:copy.deepcopy(g.doc[key]) for key in
               ('skins','nodes','meshes','materials','animations')}
    before=_audit(g,tracks,ibm,skin,entries,samples,range(FRAMES),{})
    world,rot,morph=_sample(g,tracks,0.)
    posed=_posed(samples,ibm,skin,world,rot,morph)
    accepted={}
    details={}
    for name,entry in entries.items():
        _,_,_,vectors=_probe(entry,(0.,0.,0.),world,rot,
                             _facepoints(entry,posed),offsets=True)
        shift=tuple(sorted(v[k] for v in vectors)[len(vectors)//2]
                    for k in range(3))
        extent=norm(shift)
        shift=mul(shift,min(1.,MAX_MOVE/extent)) if extent>.0001 else (0.,0.,0.)
        prior=_audit(g,tracks,ibm,skin,{name:entry},
                     {i:samples[i] for i in entry['vertices']},COARSE,{})[name]
        provisional=None
        coarse_candidates=0
        for scale in (.25,.5,.75,1.):
            trial=mul(shift,scale)
            if norm(trial)<.0001:
                continue
            candidate=_audit(g,tracks,ibm,skin,{name:entry},
                 {i:samples[i] for i in entry['vertices']},
                 COARSE,{name:trial})[name]
            coarse_candidates+=1
            valid,_=gate(prior,candidate)
            if valid and (provisional is None or
                (candidate['embedded']+candidate['detached'],
                 candidate['maxDistance']) <
                (provisional[1]['embedded']+provisional[1]['detached'],
                 provisional[1]['maxDistance'])):
                provisional=(trial,candidate)
        candidate=None
        reason='no_safe_9_pose_candidate'
        if provisional:
            candidate=_audit(g,tracks,ibm,skin,{name:entry},
                      {i:samples[i] for i in entry['vertices']},
                      range(FRAMES),{name:provisional[0]})[name]
            good,reason=gate(before[name],candidate)
            if good:
                accepted[name]=provisional[0]
        details[name]={
            'baseline':before[name],
            'candidate':candidate,
            'reason':reason if name not in accepted else 'sampled_risk_reduced',
            'accepted':name in accepted,
            'coarseCandidates':coarse_candidates,
            'proposedVectorMeters':list(shift),
            'appliedVectorMeters':list(accepted.get(name,(0.,0.,0.))),
        }
    for name,delta in accepted.items():
        if norm(delta)>MAX_MOVE+1e-8:
            raise ValueError('Out of bounds thumb correction')
        g.doc['nodes'][entries[name]['node']]['translation']=list(delta)
    for key in ('skins','meshes','materials','animations'):
        if g.doc[key]!=originals[key]:
            raise ValueError('Modified original character or 3D animation')
    for idx,node in enumerate(g.doc['nodes']):
        before_node=originals['nodes'][idx]
        if idx in {entries[name]['node'] for name in accepted}:
            check=copy.deepcopy(node)
            check['translation']=copy.deepcopy(before_node['translation'])
            if check!=before_node:
                raise ValueError('Changed nail hierarchy or rotation')
        elif node!=before_node:
            raise ValueError('Changed unrelated nail or body node')
    g.doc['extras'].update({
        'thumbNail3dFitVersion':937,
        'sourceNailLodSha256':hashlib.sha256(raw).hexdigest(),
        'thumbsAdjusted':len(accepted),
        'thumbsUnresolved':2-len(accepted),
        'thumbMaxTranslationMeters':MAX_MOVE,
        'artistNailReviewComplete':False,
        'fullThumbAnatomyComplete':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    output=g.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Thumb fitting exceeded mobile file budget')
    exported=GLB(output,expected_sha=None)
    for name,entry in entries.items():
        if any(abs(a-b)>1e-10 for a,b in zip(
            exported.doc['nodes'][entry['node']]['translation'],
            accepted.get(name,(0.,0.,0.)))):
            raise ValueError('Nodal thumb translation not preserved')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'thumbsReviewed':2,
        'thumbsAdjusted':len(accepted),
        'thumbsUnresolved':2-len(accepted),
        'acceptedOffsetsMeters':{k:list(v) for k,v in accepted.items()},
        'sampledFullFrames':FRAMES,
        'sampledRateHz':FPS,
        'thumbRecords':details,
        'unchangedRigJoints':55,
        'unchangedMorphTargets':8,
        'newNailVertices':0,
        'expertAnatomyCertified':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'outputBytes':len(output),
        'approved':False,'enabled':False,
    }


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for eid in EXERCISES:
        raw=(source_dir/(eid+'_v936_nail_lod_mobile_qa.glb')).read_bytes()
        output,report=fit(raw,eid)
        (output_dir/(eid+'_v937_thumb_nail_fit_mobile_qa.glb')).write_bytes(
            output)
        reports.append(report)
    result={
        'schema':'stk_v937_thumb_nail_3d_triangle_contact_fit_qa',
        'catalogCount':229,'pilotCount':3,
        'thumbsReviewed':6,
        'thumbsAdjusted':sum(r['thumbsAdjusted'] for r in reports),
        'thumbsUnresolved':sum(r['thumbsUnresolved'] for r in reports),
        'continuousCollisionCertified':False,
        'expertAnatomyCertified':False,
        'physicalDeviceVerified':False,'productionReady':False,
        'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output_dir/'thumb_nail_fit_v937_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    x=build(args.input,args.output)
    print(json.dumps({'schema':x['schema'],'adjusted':x['thumbsAdjusted'],
                      'approved':False},indent=2))
