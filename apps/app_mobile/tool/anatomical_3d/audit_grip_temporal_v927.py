#!/usr/bin/env python3
"""STK Haven v9.27: 60 Hz offline real-skin fingertip/bar comparison.

Compare the 55-joint v9.25 baseline against the v9.26 bounded grip candidate
across 241 interpolated poses. Sample real skinned vertices, 8 morph targets
and the animated finite bar cylinder. READ ONLY: never writes a GLB.
Sampling does not certify collision freedom between frames or triangle faces.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import DIGITS,SIDES,quaternion_distance_degrees
from retarget_cc0_glb import EXERCISES,qrot,qconj
from exercise_surface_collision_v911 import (
    _samplers,_sample,_skin_vertex,capped_cylinder_sdf,
)
from audit_finger_contact_bounds_v923 import _read_refined
from optimize_finger_grip_v926 import _distal_vertices,MAX_DEEPER_METERS
from review_fingertip_mesh_v919 import SHAFT_MIN_X,SHAFT_MAX_X,SHAFT_RADIUS

FPS=60
FRAMES=241
KEY_PERIOD=6
DEEP_METERS=-.002
NEAR_METERS=.010


def regression(before,after):
    if not math.isfinite(before) or not math.isfinite(after):
        raise ValueError('Invalid signed distance')
    return after < before-MAX_DEEPER_METERS-1e-9


def _verify(baseline,candidate,exercise):
    if exercise not in EXERCISES:
        raise ValueError('Unrecognized exercise')
    a,p,j,w,m,ibm,skin,_=_read_refined(baseline,exercise)
    b,p2,j2,w2,m2,ibm2,skin2,_=_read_refined(candidate,exercise)
    meta=a.doc['extras']; target=b.doc['extras']
    if (meta.get('palmThumbRetopologyVersion')!=925 or
            meta.get('fingerContactOptimizerVersion') is not None or
            target.get('fingerContactOptimizerVersion')!=926 or
            target.get('sourcePalmWebSha256')!=hashlib.sha256(baseline).hexdigest() or
            any(x.get('approved') is not False or x.get('enabled') is not False
                for x in (meta,target))):
        raise ValueError('Only original quarantined v9.25/v9.26 pair accepted')
    for field in ('skins','nodes','meshes','materials','animations'):
        if a.doc[field]!=b.doc[field]:
            raise ValueError('Skin/equipment/clip structure changed: '+field)
    if any(x!=y for x,y in (
            (p,p2),(j,j2),(w,w2),(m,m2),(ibm,ibm2),(skin,skin2))):
        raise ValueError('Grip review cannot compare different body meshes')
    attr=a.doc['meshes'][0]['primitives'][0]['attributes']
    if a.accessor(attr['NORMAL'])!=b.accessor(attr['NORMAL']):
        raise ValueError('Skin surface normals changed')
    tracks_a,tracks_b=_samplers(a),_samplers(b)
    if tracks_a.keys()!=tracks_b.keys():
        raise ValueError('Unexpected glTF animation channel')
    finger_nodes={
        a.by_name[f'{digit}_0{k}_{side}']
        for side in SIDES for digit in DIGITS for k in (1,2,3)
    }
    edited=[]
    for key,v in tracks_a.items():
        after=tracks_b[key]
        if v==after:
            continue
        if key[1]!='rotation' or key[0] not in finger_nodes or (
                v[0]!=after[0] or v[-1]!=after[-1]):
            raise ValueError('Non-finger channel or animation loop edited')
        if max(quaternion_distance_degrees(x,y) for x,y in zip(v,after))>3.02:
            raise ValueError('Anatomical joint correction above 3 degrees')
        edited.append(key[0])
    if len(edited)>10 or len(edited)!=target.get('fingerCorrectedTracks'):
        raise ValueError('Wrong changed finger rotation count')
    selected=_distal_vertices(a,p,j,w,skin)
    return a,b,tracks_a,tracks_b,selected,(p,m,w,j,ibm,skin),len(edited)


def _measure(glb,tracks,selected,mesh,seconds):
    if not math.isfinite(seconds) or not 0.<=seconds<=4.:
        raise ValueError('Invalid glTF time')
    p,m,w,j,ibm,skin=mesh
    world,rot,activation=_sample(glb,tracks,seconds)
    bar_node=glb.by_name['STK_EXERCISE_BAR']
    bar=world[bar_node]
    inv=qconj(rot[bar_node])
    signed={}
    for index in {i for row in selected.values() for i in row}:
        vertex=_skin_vertex(
            p[index],[shape[index] for shape in m],
            w[index],j[index],ibm,world,rot,skin,activation)
        local=qrot(inv,tuple(vertex[k]-bar[k] for k in range(3)))
        signed[index]=capped_cylinder_sdf(
            local,SHAFT_MIN_X,SHAFT_MAX_X,SHAFT_RADIUS)
    output={}
    for digit,indices in selected.items():
        gaps=[signed[i] for i in indices]
        if len(gaps)<6 or not all(math.isfinite(x) for x in gaps):
            raise ValueError('Incomplete skinned finger surface')
        output[digit]=(min(gaps),
                       sum(max(0.,x-.0015) for x in gaps)/len(gaps))
    return output


def review(baseline,candidate,exercise):
    a,b,tracks_a,tracks_b,selected,mesh,edited=_verify(
        baseline,candidate,exercise)
    per={digit:dict(
        baselineTrace=[],candidateTrace=[],regressionFrames=[],
        betweenKeyRegressions=[],deepBefore=0,deepAfter=0,
        introducedDeep=0,nearBefore=0,nearAfter=0,
        positiveBefore=0.,positiveAfter=0.) for digit in selected}
    for frame in range(FRAMES):
        t=frame/FPS
        before=_measure(a,tracks_a,selected,mesh,t)
        after=_measure(b,tracks_b,selected,mesh,t)
        for digit in selected:
            stat=per[digit]
            signed_a,gap_a=before[digit]
            signed_b,gap_b=after[digit]
            stat['baselineTrace'].append(round(signed_a,7))
            stat['candidateTrace'].append(round(signed_b,7))
            stat['positiveBefore']+=gap_a
            stat['positiveAfter']+=gap_b
            stat['deepBefore']+=int(signed_a<DEEP_METERS)
            stat['deepAfter']+=int(signed_b<DEEP_METERS)
            stat['introducedDeep']+=int(signed_a>=DEEP_METERS and
                                        signed_b<DEEP_METERS)
            stat['nearBefore']+=int(abs(signed_a)<=NEAR_METERS)
            stat['nearAfter']+=int(abs(signed_b)<=NEAR_METERS)
            if regression(signed_a,signed_b):
                stat['regressionFrames'].append(frame)
                if frame%KEY_PERIOD:
                    stat['betweenKeyRegressions'].append(frame)
    details={}
    for digit,stat in per.items():
        base=stat.pop('positiveBefore')
        end=stat.pop('positiveAfter')
        old=stat.pop('baselineTrace')
        new=stat.pop('candidateTrace')
        if len(old)!=FRAMES or len(new)!=FRAMES:
            raise ValueError('Incomplete interpolated animation')
        details[digit]={
            **stat,
            'baselineSignedDistanceTraceMeters':old,
            'candidateSignedDistanceTraceMeters':new,
            'sampledFrames':FRAMES,
            'baselineMinSignedMeters':min(old),
            'candidateMinSignedMeters':min(new),
            'baselineMeanPositiveGapMeters':round(base/FRAMES,7),
            'candidateMeanPositiveGapMeters':round(end/FRAMES,7),
            'maxAdditionalPenetrationMeters':round(
                max(0.,max(x-y for x,y in zip(old,new))),7),
            'noRegressionAtSampledPoses':not stat['regressionFrames'],
            'approved':False,
        }
    return {
        'exerciseId':exercise,'baselineVersion':925,'candidateVersion':926,
        'sourceSha256':hashlib.sha256(baseline).hexdigest(),
        'candidateSha256':hashlib.sha256(candidate).hexdigest(),
        'rigJoints':55,'morphTargets':8,'changedFingerTracks':edited,
        'frames':FRAMES,'fps':FPS,'betweenKeyframeSamples':200,
        'fingerResults':details,
        'regressionFramesTotal':sum(len(x['regressionFrames'])
                                    for x in details.values()),
        'no60HzSampleRegressions':all(x['noRegressionAtSampledPoses']
                                    for x in details.values()),
        'continuousCollisionCertified':False,
        'triangleInteriorIntersectionCertified':False,
        'contactIKCompleted':False,'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    }


def build(baseline_folder,candidate_folder,output):
    baseline_folder=Path(baseline_folder)
    candidate_folder=Path(candidate_folder)
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        source=(baseline_folder/(exercise+'_v925_palm_web_topology_mobile_qa.glb'
                                 )).read_bytes()
        revised=(candidate_folder/(exercise+'_v926_grip_optimized_mobile_qa.glb'
                                   )).read_bytes()
        reports.append(review(source,revised,exercise))
    result={
        'schema':'stk_v927_interpolated_skin_grip_60hz_qa',
        'catalogCount':229,'pilotCount':3,
        'sampledFramesPerExercise':FRAMES,'sampleRateHz':FPS,
        'samplesBetweenOriginalKeyframes':200,
        'noProductionMutation':True,
        'continuousCollisionCertified':False,
        'fullFingerIKCompleted':False,'professionalAnatomyApproved':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,'productionReady':False,
        'pilots':reports,
    }
    (output/'finger_bar_temporal_v927_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--baseline',required=True,type=Path)
    cli.add_argument('--candidate',required=True,type=Path)
    cli.add_argument('--output',required=True,type=Path)
    args=cli.parse_args()
    print(json.dumps({
        'schema':build(args.baseline,args.candidate,args.output)['schema'],
        'approved':False,'enabled':False,
    },indent=2))
