#!/usr/bin/env python3
"""v9.38 QA: left thumb plate tilt + 3D translation, preserve v9.37 right.

Search rigid nail quaternion rotations around its own geometric center,
using actual morphed/skinned distal skin triangles. Reject candidates that
worsen possible embedded probes, detached probes or max gap at 241 poses.
Not continuous collision detection or expert anatomical validation.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import fit_thumb_nail_skin_v937 as prev
from retarget_cc0_glb import GLB,EXERCISES,add,sub,mul,unit,norm,qrot
from refine_fingertip_topology_v922 import MAX_MOBILE_BYTES

LEFT='thumb_l'
ANGLES=(-18,-12,-6,0,6,12,18)
FRACTIONS=(.25,.5,.75,1.)
LIFTS=(0.,.0006,.0012)
MAX_VERTEX_MOVE=.012
MAX_NODE_MOVE=.012
MAX_FULL_REVIEWS=12


def qaxis(axis,degrees):
    if abs(degrees)>18 or norm(axis)<.01 or not all(
            math.isfinite(x) for x in (*axis,degrees)):
        raise ValueError('Unsafe nail rotation')
    a=unit(axis)
    half=math.radians(degrees)/2
    return (*mul(a,math.sin(half)),math.cos(half))


def gate(old,new):
    return prev.gate(old,new)


def _centre(points):
    return tuple(sum(p[k] for p in points)/len(points) for k in range(3))


def _rotated(entry,centre,q):
    result=dict(entry)
    result['probes']=[add(centre,qrot(q,sub(p,centre)))
                      for p in entry['probes']]
    return result


def _frames(g,tracks,ibm,skin,entry,samples,indices):
    cached=[]
    for frame in indices:
        world,rot,morph=prev._sample(g,tracks,frame/prev.FPS)
        p=prev._posed(samples,ibm,skin,world,rot,morph)
        cached.append((world,rot,prev._facepoints(entry,p)))
    return cached


def _measure(entry,cache,offset):
    emb=det=0
    distance=0.
    for world,rot,faces in cache:
        a,b,c,_=prev._probe(entry,offset,world,rot,faces)
        emb+=a
        det+=b
        distance=max(distance,c)
    return {
        'embedded':emb,'detached':det,
        'maxDistance':round(distance,8),
        'frames':len(cache),'probes':len(cache)*len(entry['probes']),
    }


def fit(v937raw,v936raw,exercise):
    if exercise not in EXERCISES or max(
            len(v937raw),len(v936raw))>MAX_MOBILE_BYTES:
        raise ValueError('Unrecognized or oversized QA GLB')
    source=GLB(v937raw,expected_sha=None)
    neutral=GLB(v936raw,expected_sha=None)
    extras=source.doc['extras']
    if (extras.get('thumbNail3dFitVersion')!=937 or
        extras.get('leftThumbPlateContourFitVersion') is not None or
        extras.get('sourceNailLodSha256')!=hashlib.sha256(v936raw).hexdigest() or
        extras.get('approved') is not False or
        extras.get('enabled') is not False):
        raise ValueError('Require unmodified inactive v9.37 and v9.36')
    for field in ('meshes','skins','animations','materials'):
        if source.doc[field]!=neutral.doc[field]:
            raise ValueError('Nail source no longer shares body and animation')
    for i,n in enumerate(source.doc['nodes']):
        if n!=neutral.doc['nodes'][i] and n.get('name')!='STK_NAIL_PLATE_thumb_r':
            raise ValueError('Existing non-right-thumb nodes changed')
    g,tracks,ibm,skin,entries,samples=prev._skin(None,exercise,v936raw)
    entry=entries[LEFT]
    node=entry['node']
    before_node=source.doc['nodes'][node]
    if before_node.get('rotation')!=[0.,0.,0.,1.] or (
        before_node.get('translation')!=[0.,0.,0.]):
        raise ValueError('Left thumb already changed')
    mesh=g.doc['meshes'][g.doc['nodes'][node]['mesh']]['primitives'][0]
    verts=g.accessor(mesh['attributes']['POSITION'])
    normals=g.accessor(mesh['attributes']['NORMAL'])
    if len(verts)!=30 or len(normals)!=30:
        raise ValueError('Not an authentic nail LOD')
    body={i:samples[i] for i in entry['vertices']}
    centre=_centre(entry['probes'])
    lateral=unit(sub(entry['probes'][5],entry['probes'][3]))
    longitudinal=unit(sub(entry['probes'][7],entry['probes'][1]))
    dorsal=unit(tuple(sum(v[k] for v in normals[:15])/15
                       for k in range(3)))
    at0=_frames(g,tracks,ibm,skin,entry,body,(0,))
    _,_,_,diffs=prev._probe(entry,(0.,0.,0.),
            at0[0][0],at0[0][1],at0[0][2],offsets=True)
    direction=tuple(sorted(v[k] for v in diffs)[len(diffs)//2]
                    for k in range(3))
    if norm(direction)>.012:
        direction=mul(direction,.012/norm(direction))
    coarse=_frames(g,tracks,ibm,skin,entry,body,prev.COARSE)
    base_coarse=_measure(entry,coarse,(0.,0.,0.))
    candidates=[]
    for axis in (lateral,longitudinal):
        for deg in ANGLES:
            q=qaxis(axis,deg)
            rotated=_rotated(entry,centre,q)
            for factor in FRACTIONS:
                for lift in LIFTS:
                    offset=add(mul(direction,factor),mul(dorsal,lift))
                    translation=add(sub(centre,qrot(q,centre)),offset)
                    if norm(translation)>MAX_NODE_MOVE or (
                       max(norm(sub(add(qrot(q,p),translation),p))
                           for p in verts)>MAX_VERTEX_MOVE):
                        continue
                    score=_measure(rotated,coarse,offset)
                    success,_=gate(base_coarse,score)
                    if success:
                        candidates.append((score,deg,q,translation,
                                           rotated,offset))
    candidates.sort(key=lambda x:(x[0]['embedded']+x[0]['detached'],
                                  x[0]['embedded'],x[0]['maxDistance'],
                                  abs(x[1]),norm(x[3])))
    full=_frames(g,tracks,ibm,skin,entry,body,range(prev.FRAMES))
    base_full=_measure(entry,full,(0.,0.,0.))
    winner=None
    evaluations=[]
    for score,deg,q,translation,rotated,offset in candidates[:MAX_FULL_REVIEWS]:
        after=_measure(rotated,full,offset)
        success,reason=gate(base_full,after)
        evaluations.append({
            'angleDegrees':deg,'beforeEmbeds':base_full['embedded'],
            'afterEmbeds':after['embedded'],
            'beforeDetachments':base_full['detached'],
            'afterDetachments':after['detached'],
            'beforeMaximumDistance':base_full['maxDistance'],
            'afterMaximumDistance':after['maxDistance'],
            'accepted':success,'reason':reason,
        })
        if success:
            winner=(deg,q,translation,after)
            break
    if winner is not None:
        _,q,translation,result=winner
        source.doc['nodes'][node]['rotation']=list(q)
        source.doc['nodes'][node]['translation']=list(translation)
    else:
        result=base_full
    source.doc['extras'].update({
        'leftThumbPlateContourFitVersion':938,
        'originalV937Sha256':hashlib.sha256(v937raw).hexdigest(),
        'leftThumbTiltAccepted':winner is not None,
        'rightThumbCorrectionPreserved':True,
        'continuousCollisionCertified':False,
        'professionalNailSculptComplete':False,
        'physicalPhonePerformanceVerified':False,
        'approved':False,'enabled':False,
    })
    output=source.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Oversized nail QA output')
    verify=GLB(output,expected_sha=None)
    old=GLB(v937raw,expected_sha=None)
    for k in ('meshes','skins','materials','animations'):
        if verify.doc[k]!=old.doc[k]:
            raise ValueError('Modified body, rig, UV or animation')
    for i,n in enumerate(old.doc['nodes']):
        newer=copy.deepcopy(verify.doc['nodes'][i])
        if i==node:
            newer['rotation']=n['rotation']
            newer['translation']=n['translation']
        if n!=newer:
            raise ValueError('Changed bone or right thumb')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(v937raw).hexdigest(),
        'resultSha256':hashlib.sha256(output).hexdigest(),
        'leftThumbAdjusted':winner is not None,
        'leftThumbTiltDegrees':winner[0] if winner else 0,
        'leftThumbTranslationMeters':list(winner[2]) if winner
            else [0.,0.,0.],
        'fullSampledFrames':prev.FRAMES,
        'coarseSampledFrames':len(prev.COARSE),
        'coarseEligibleCandidates':len(candidates),
        'fullCandidatesChecked':len(evaluations),
        'baseline':base_full,
        'final':result,
        'candidateEvaluations':evaluations,
        'rightThumbV937Preserved':True,
        'rigJointsUnchanged':55,'morphsUnchanged':8,
        'continuousCollisionCertified':False,
        'expertAnatomyApproved':False,
        'physicalDeviceVerified':False,'outputBytes':len(output),
        'approved':False,'enabled':False,
    }


def build(source937,source936,target):
    source937,source936,target=Path(source937),Path(source936),Path(target)
    target.mkdir(parents=True,exist_ok=True)
    results=[]
    for eid in EXERCISES:
        raw=(source937/(eid+'_v937_thumb_nail_fit_mobile_qa.glb')
             ).read_bytes()
        earlier=(source936/(eid+'_v936_nail_lod_mobile_qa.glb')
                 ).read_bytes()
        new,report=fit(raw,earlier,eid)
        (target/(eid+'_v938_left_thumb_angle_mobile_qa.glb')
         ).write_bytes(new)
        results.append(report)
    summary={
        'schema':'stk_v938_left_thumb_roll_pitch_skin_contact_qa',
        'pilotCount':3,'catalogCount':229,
        'leftThumbsAdjusted':sum(r['leftThumbAdjusted'] for r in results),
        'leftThumbsReviewed':3,'rightThumbUnchanged':True,
        'expertAnatomyApproved':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,'productionReady':False,
        'approved':False,'enabled':False,'pilots':results,
    }
    (target/'left_thumb_angle_v938_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--source-v937',type=Path,required=True)
    cli.add_argument('--neutral-v936',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    a=cli.parse_args()
    print(json.dumps(build(a.source_v937,a.neutral_v936,a.output),
                     indent=2)[:2500])
