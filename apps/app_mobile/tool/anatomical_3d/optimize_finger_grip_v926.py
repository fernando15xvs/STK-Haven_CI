#!/usr/bin/env python3
"""STK Haven v9.26: opt-in skinned fingertip/bar grip candidate (QA only).

Coordinate search over 30 existing finger tracks using real morphed/skinned
distal vertices at 1/2/3 seconds, bounded local X corrections, and per-pose
penetration guards. Not full IK or continuous triangle collision detection.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import EXERCISES, GLB, qmul, qnorm, qx, qrot, qconj
from animate_hand_grip_v917 import DIGITS, SIDES, quaternion_distance_degrees
from exercise_surface_collision_v911 import (
    _samplers, _skin_vertex, capped_cylinder_sdf,
)
from audit_finger_contact_bounds_v923 import _read_refined
from review_fingertip_mesh_v919 import SHAFT_MIN_X, SHAFT_MAX_X, SHAFT_RADIUS
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES

KEY_COUNT=41
FRAMES=(10,20,30)
ANGLES=(-3.,-1.5,1.5,3.)
MAX_EXTRA_DEGREES=3.
MAX_REST_DEGREES=12.
MAX_STEP_EXTRA_DEGREES=.65
MAX_DEEPER_METERS=.0005
MIN_IMPROVEMENT=1e-9


def envelope(t):
    if not math.isfinite(t) or not 0<=t<=4:
        raise ValueError('Invalid animation time')
    return 0. if t in (0.,4.) else math.sin(math.pi*t/4.)**2


def corrected_track(poses, degrees):
    if len(poses)!=KEY_COUNT or not math.isfinite(degrees) or abs(degrees)>MAX_EXTRA_DEGREES:
        raise ValueError('Finger animation leaves ROM guard')
    result=[]
    for k,old in enumerate(poses):
        if len(old)!=4 or not .999<math.sqrt(sum(x*x for x in old))<1.001:
            raise ValueError('Nonunit source quaternion')
        amount=math.radians(degrees)*envelope(k*.1)
        result.append(tuple(old) if amount==0 else qnorm(qmul(old,qx(amount))))
    if result[0]!=tuple(poses[0]) or result[-1]!=tuple(poses[-1]):
        raise ValueError('New finger loop seam')
    old_step=max(quaternion_distance_degrees(a,b) for a,b in zip(poses,poses[1:]))
    new_step=max(quaternion_distance_degrees(a,b) for a,b in zip(result,result[1:]))
    if new_step>old_step+MAX_STEP_EXTRA_DEGREES:
        raise ValueError('Finger speed guard breached')
    return result


def _distal_vertices(glb,positions,joints,weights,skin):
    found={}
    for side in SIDES:
        for digit in DIGITS:
            label=f'{digit}_{side}'
            bone=glb.by_name[f'{digit}_03_{side}']
            palette=skin.index(bone)
            ranked=[]
            for i,(ji,wi) in enumerate(zip(joints,weights)):
                w=sum(float(x) for j,x in zip(ji,wi) if int(j)==palette)
                if w>=.20:
                    ranked.append((-w,i))
            if len(ranked)<6:
                raise ValueError('Missing real distal skin '+label)
            found[label]=[i for _,i in sorted(ranked)[:28]]
    if len(found)!=10:
        raise ValueError('Incomplete bilateral finger surface')
    return found


def _pose(glb,channels,frame,corrections):
    if frame not in FRAMES:
        raise ValueError('Not an audited animation frame')
    local={}
    morph=None
    for (node,path),values in channels.items():
        if path=='weights':
            morph=[values[frame*8+i][0] for i in range(8)]
            continue
        obj=glb.nodes[node]
        p,q=local.get(node,(tuple(obj.get('translation',(0.,0.,0.))),
                             tuple(obj.get('rotation',(0.,0.,0.,1.)))))
        if path=='translation':
            p=tuple(values[frame])
        elif path=='rotation':
            q=tuple(values[frame])
            if node in corrections:
                angle=math.radians(corrections[node])*envelope(frame*.1)
                q=qnorm(qmul(q,qx(angle)))
        else:
            raise ValueError('Unexpected animation channel type')
        local[node]=(p,q)
    if morph is None or len(morph)!=8:
        raise ValueError('Eight morph channels are required')
    world,rotations=glb.world(local)
    return world,rotations,morph


def _distance(glb,channels,frame,corrections,ids,mesh,bar_node):
    positions,morphs,weights,joints,ibm,skin=mesh
    world,rotations,activation=_pose(glb,channels,frame,corrections)
    bar=world[bar_node]
    inverse=qconj(rotations[bar_node])
    signed=[]
    for i in ids:
        p=_skin_vertex(positions[i],[shape[i] for shape in morphs],
                        weights[i],joints[i],ibm,world,rotations,skin,activation)
        local=qrot(inverse,tuple(p[k]-bar[k] for k in range(3)))
        signed.append(capped_cylinder_sdf(
            local,SHAFT_MIN_X,SHAFT_MAX_X,SHAFT_RADIUS))
    if len(signed)<6 or not all(math.isfinite(x) for x in signed):
        raise ValueError('Invalid skinned fingertip contact')
    # Approach a 1.5mm standoff, penalize any observed penetration strongly.
    score=sum(min(.09,max(0.,v-.0015))**2+9.*max(0.,-v)**2
              for v in signed)/len(signed)
    return score,min(signed)


def _evaluate(glb,channels,changes,ids,mesh,bar):
    return [_distance(glb,channels,frame,changes,ids,mesh,bar)
            for frame in FRAMES]


def _solve(glb,channels,selected,mesh,bar):
    changes={}
    reviews={}
    for side in SIDES:
        for digit in DIGITS:
            label=f'{digit}_{side}'
            baseline=_evaluate(glb,channels,changes,selected[label],mesh,bar)
            baseline_score=sum(x[0] for x in baseline)
            best=(baseline_score,None,0.,baseline)
            tested=0
            for segment in (1,2,3):
                bone=f'{digit}_0{segment}_{side}'
                node=glb.by_name[bone]
                track=channels.get((node,'rotation'))
                if track is None or len(track)!=KEY_COUNT:
                    raise ValueError('Missing original finger rotation '+bone)
                rest=tuple(glb.nodes[node].get('rotation',(0.,0.,0.,1.)))
                for degrees in ANGLES:
                    candidate_track=corrected_track(track,degrees)
                    tested+=1
                    if max(quaternion_distance_degrees(rest,q)
                           for q in candidate_track)>MAX_REST_DEGREES+.02:
                        continue
                    proposal={**changes,node:degrees}
                    measurements=_evaluate(
                        glb,channels,proposal,selected[label],mesh,bar)
                    if any(n[1]<o[1]-MAX_DEEPER_METERS
                           for o,n in zip(baseline,measurements)):
                        continue
                    trial=sum(x[0] for x in measurements)
                    if trial<best[0]-MIN_IMPROVEMENT:
                        best=(trial,node,degrees,measurements)
            accepted=best[1] is not None
            if accepted:
                changes[best[1]]=best[2]
            reviews[label]={
                'candidatesConsidered':tested,
                'accepted':accepted,
                'joint':glb.nodes[best[1]]['name'] if accepted else None,
                'degrees':best[2],
                'baselineScore':baseline_score,
                'candidateScore':best[0],
                'baselineWorstSignedMeters':min(m[1] for m in baseline),
                'candidateWorstSignedMeters':min(m[1] for m in best[3]),
                'sampledFrames':list(FRAMES),
                'reviewRequired':True,
            }
    return changes,reviews


def optimize(raw,exercise):
    glb,p,j,w,morph,ibm,skin,_=_read_refined(raw,exercise)
    doc=glb.doc
    meta=doc['extras']
    if (meta.get('palmThumbRetopologyVersion')!=925 or
            meta.get('palmThumbSculptVersion')!=924 or
            meta.get('fingerContactOptimizerVersion') is not None or
            meta.get('approved') is not False or meta.get('enabled') is not False):
        raise ValueError('Require original disabled v9.25 pilot')
    original={k:copy.deepcopy(doc[k])
              for k in ('skins','nodes','meshes','animations','materials')}
    channels=_samplers(glb)
    finger_nodes={glb.by_name[f'{digit}_0{segment}_{side}']
                  for side in SIDES for digit in DIGITS
                  for segment in (1,2,3)}
    tracks={}
    for channel in doc['animations'][0]['channels']:
        target=channel['target']
        if target['node'] in finger_nodes and target['path']=='rotation':
            sampler=doc['animations'][0]['samplers'][channel['sampler']]
            if (sampler.get('interpolation')!='LINEAR' or
                    target['node'] in tracks):
                raise ValueError('Invalid 30 digit rotation tracks')
            tracks[target['node']]=sampler['output']
    if len(tracks)!=30:
        raise ValueError('Expected exactly 30 existing finger tracks')
    distal=_distal_vertices(glb,p,j,w,skin)
    mesh=(p,morph,w,j,ibm,skin)
    bar=glb.by_name['STK_EXERCISE_BAR']
    changes,reviews=_solve(glb,channels,distal,mesh,bar)
    patches={tracks[node]:corrected_track(
        channels[(node,'rotation')],degrees)
             for node,degrees in changes.items()}
    if len(patches)!=len(changes):
        raise ValueError('Unexpected shared animation output accessor')
    _patch_view(glb,patches)
    meta.update({
        'fingerContactOptimizerVersion':926,
        'sourcePalmWebSha256':hashlib.sha256(raw).hexdigest(),
        'candidateOnly':True,'fingerCorrectedTracks':len(changes),
        'fullFingerIKComplete':False,
        'fullSurfaceCollisionCertified':False,
        'biomechanicsApproved':False,'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    if any(doc[k]!=v for k,v in original.items()):
        raise ValueError('Optimizer changed geometry, rig or clip graph')
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Grip candidate exceeds mobile QA size')
    check=GLB(output,expected_sha=None)
    exported=_samplers(check)
    for key,values in channels.items():
        now=exported[key]
        if key[0] not in changes and now!=values:
            raise ValueError('Unintended non-finger channel changed')
        if key[0] in changes and (len(now)!=KEY_COUNT or
                                  now[0]!=values[0] or now[-1]!=values[-1]):
            raise ValueError('Loop seam or sampled output corrupted')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'rigJoints':55,'morphTargets':8,
        'fingerTracksPreserved':30,
        'fingersEvaluated':10,'editedTracks':len(changes),
        'sampleTimesSeconds':[1.,2.,3.],
        'maxExtraJointDegrees':MAX_EXTRA_DEGREES,
        'surfaceSkinSamplesUsed':True,
        'fingerReports':reviews,
        'fullContactIKCompleted':False,'collisionFreeCertified':False,
        'anatomyApproved':False,'physicalDeviceVerified':False,
        'outputBytes':len(output),
        'approved':False,'enabled':False,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source/f'{exercise}_v925_palm_web_topology_mobile_qa.glb'
             ).read_bytes()
        result,report=optimize(raw,exercise)
        (output/f'{exercise}_v926_grip_optimized_mobile_qa.glb'
         ).write_bytes(result)
        reports.append(report)
    summary={
        'schema':'stk_v926_bounded_skinned_bar_grip_qa',
        'catalogCount':229,'pilotCount':3,
        'rigJoints':55,'fingerTracks':30,
        'fullContactIKCompleted':False,
        'continuousCollisionCertified':False,'physicalDeviceVerified':False,
        'approved':False,'enabled':False,'productionReady':False,
        'pilots':reports,
    }
    (output/'grip_optimizer_v926_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    report=build(args.input,args.output)
    print(json.dumps({'schema':report['schema'],'pilots':3,
                      'approved':False},indent=2))
