#!/usr/bin/env python3
"""v9.17 experimental articulated finger grip for three *disabled* STK pilots.

Drive the existing 30 finger joints (15 per hand) with a small, loop-safe
4-second grip pressure envelope. Do not alter the hand/wrist, elbow, torso,
bar, bench, skinning, morphs, geometry or original exercise IK tracks.
Finger-to-bar skin contact is *NOT* proven by this procedural preview.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import (
    GLB, SOURCE_SHA, qmul, qnorm, qx, norm, sub,
)
from build_master_anatomy_v8 import EXERCISE_IDS

DIGITS = ('index', 'middle', 'ring', 'pinky', 'thumb')
SIDES = ('l', 'r')
SEGMENTS = (1, 2, 3)
KEYFRAMES = 41
FPS = 30
DURATION = 4.0
MAX_FINGER_DEG = 7.0
MAX_DELTA_BETWEEN_KEYS_DEG = 1.5
MAX_MOBILE_BYTES = 1400*1024
MAX_ARTIST_BYTES = 6*1024*1024
EXERCISE_PRESSURE = {
    'ex_bench_press': 1.00,
    'ex_barbell_row': .85,
    'ex_squat': .65,
}
DIGIT_STRENGTH = {
    'index': .90, 'middle': 1.00, 'ring': .88,
    'pinky': .76, 'thumb': .62,
}
SEGMENT_STRENGTH = {1:.70,2:1.00,3:.62}

def finger_names():
    return tuple(f'{digit}_0{segment}_{side}'
                 for side in SIDES for digit in DIGITS for segment in SEGMENTS)

FINGERS = finger_names()
assert len(FINGERS)==30

def quaternion_distance_degrees(a,b):
    cosine=abs(sum(x*y for x,y in zip(a,b)))
    cosine=min(1.,max(0.,cosine))
    return math.degrees(2*math.acos(cosine))

def grip_pressure(seconds,exercise):
    if exercise not in EXERCISE_PRESSURE:
        raise ValueError('Unknown exercise grip curve')
    if not math.isfinite(seconds) or not 0<=seconds<=DURATION:
        raise ValueError('Invalid exercise time')
    # Positive and monotone into peak; loop endpoints EXACTLY zero.
    value=math.sin(math.pi*(seconds/DURATION))**2
    return max(0.,value)*EXERCISE_PRESSURE[exercise]

def valid_source(glb,exercise,high):
    doc=glb.doc
    extras=doc.get('extras',{})
    if (exercise not in EXERCISE_IDS or
        extras.get('exerciseId')!=exercise or
        extras.get('sourceSha256')!=SOURCE_SHA or
        extras.get('masterExercisePilotVersion')!=910 or
        extras.get('torsoContourArtVersion')!=916 or
        extras.get('torsoContourOutput')!=('authoring' if high else 'mobile') or
        extras.get('approved') is not False or
        extras.get('enabled') is not False or
        len(doc.get('skins',[]))!=1 or
        len(doc['skins'][0]['joints'])!=55 or
        len(doc.get('animations',[]))!=1 or
        len(doc.get('meshes',[]))!=(3 if exercise=='ex_bench_press' else 2) or
        len(doc['meshes'][0]['primitives'])!=12 or
        any(name not in glb.by_name for name in FINGERS)):
        raise ValueError('Untrusted or incomplete 55-bone v9.16 pilot')
    clip=doc['animations'][0]
    if clip['name']!=f'STK_MASTER_55_{exercise}_V910_IK_UNAPPROVED':
        raise ValueError('Exercise clip identity changed')
    if len(FINGERS)!=len(set(FINGERS)):
        raise ValueError('Duplicate finger joints')
    names={glb.by_name[name] for name in FINGERS}
    if not names.issubset(set(doc['skins'][0]['joints'])):
        raise ValueError('Finger controls not weighted into 55-joint skin')
    targets=[(v['target']['node'],v['target']['path'])
             for v in clip['channels']]
    if len(targets)!=len(set(targets)) or any(
            (node,'rotation') in targets for node in names):
        raise ValueError('Finger animation already bound or duplicate targets')
    if any(s.get('interpolation')!='LINEAR' for s in clip['samplers']):
        raise ValueError('Nonlinear reference IK cannot be extended')
    input_sampler=clip['samplers'][0]
    times=[row[0] for row in glb.accessor(input_sampler['input'])]
    if (len(times)!=KEYFRAMES or any(abs(t-.1*i)>1e-5 for i,t in
                                     enumerate(times))):
        raise ValueError('Requires 41 original 0-4 second keyframes')
    if doc['extras'].get('handGripArtVersion') is not None:
        raise ValueError('Finger animation derivative already exists')
    return clip,times,targets

def solve(raw,exercise,high=False):
    glb=GLB(raw,expected_sha=None)
    clip,times,old_targets=valid_source(glb,exercise,high)
    prior_clip_channels=len(clip['channels'])
    before_positions={}
    for name in ('hand_l','hand_r','foot_l','foot_r',
                 'STK_EXERCISE_BAR'):
        before_positions[name]=list(glb.nodes[glb.by_name[name]].items())
    new_tracks=[]
    maximum=0.
    maximum_step=0.
    nontrivial=0
    # One accessor of 41 floats is shared across all 30 new finger channels.
    keyframes=glb.append(times,1,'SCALAR')
    for side in SIDES:
        for digit in DIGITS:
            for segment in SEGMENTS:
                name=f'{digit}_0{segment}_{side}'
                idx=glb.by_name[name]
                node=glb.nodes[idx]
                rest=tuple(float(x) for x in node.get(
                    'rotation',(0,0,0,1)))
                if len(rest)!=4 or not .999<norm(rest)<1.001:
                    raise ValueError('Bad original finger rest rotation')
                # The existing pose already closes the hand somewhat around
                # equipment. Add small relative flex; do not assume exact
                # fingertip contact with cylinder/bar surface.
                amplitude=math.radians(MAX_FINGER_DEG *
                    DIGIT_STRENGTH[digit] *
                    SEGMENT_STRENGTH[segment])
                samples=[]
                for seconds in times:
                    angle=amplitude*grip_pressure(seconds,exercise)
                    pose=qnorm(qmul(rest,qx(angle)))
                    samples.append(pose)
                    maximum=max(maximum,abs(math.degrees(angle)))
                for a,b in zip(samples,samples[1:]):
                    gap=quaternion_distance_degrees(a,b)
                    maximum_step=max(maximum_step,gap)
                    if gap>MAX_DELTA_BETWEEN_KEYS_DEG:
                        raise ValueError('Unnatural per-frame finger jump')
                if quaternion_distance_degrees(samples[0],samples[-1])>1e-5:
                    raise ValueError('Finger animation loop seam')
                if quaternion_distance_degrees(samples[0],samples[20])>.20:
                    nontrivial+=1
                data=glb.append(samples,4,'VEC4')
                clip['samplers'].append({
                    'input':keyframes,'output':data,
                    'interpolation':'LINEAR',
                })
                clip['channels'].append({
                    'sampler':len(clip['samplers'])-1,
                    'target':{'node':idx,'path':'rotation'},
                })
                new_tracks.append(name)
    for name,items in before_positions.items():
        if list(glb.nodes[glb.by_name[name]].items())!=items:
            raise ValueError('Wrist, foot or bar neutral transform edited')
    if (len(new_tracks)!=30 or nontrivial<22 or
        len(clip['channels'])!=prior_clip_channels+30):
        raise ValueError('Insufficient finger animation tracks')
    if maximum>MAX_FINGER_DEG+.01:
        raise ValueError('Finger pose excursion outside QA envelope')
    glb.doc['extras']=dict(glb.doc['extras'],
        handGripArtVersion=917,
        handGripFingerTracks=30,
        handGripRangeDegrees=round(maximum,5),
        handGripWristIKUnchanged=True,
        handGripArtistReviewRequired=True,
        fingerSurfaceToBarContactValidated=False,
        approved=False,enabled=False,physicalDeviceMeasured=False)
    output=glb.bytes()
    limit=MAX_ARTIST_BYTES if high else MAX_MOBILE_BYTES
    if len(output)>limit:
        raise ValueError('Finger animation exceeds current GLB size guard')
    report={
        'version':917,'exerciseId':exercise,'source':'v9.16_cc0_master55',
        'highResolution':high,'jointCount':55,
        'fingerJointChannelsAdded':len(new_tracks),
        'fingerJointNames':new_tracks,
        'existingChannelsPreserved':prior_clip_channels,
        'maxFingerExcursionDegrees':round(maximum,5),
        'maxPerKeyframeAngularStepDegrees':round(maximum_step,5),
        'loopClosureToleranceDegrees':.00001,
        'wristIKUnchanged':True,
        'barMotionUnchanged':True,
        'fingertipSurfaceContactCertified':False,
        'originalBytes':len(raw),'outputBytes':len(output),
        'originalSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'approved':False,'enabled':False,
    }
    return output,report

def build(folder,output):
    source=Path(folder)
    target=Path(output)
    target.mkdir(parents=True,exist_ok=True)
    all_reports=[]
    for exercise in EXERCISE_IDS:
        for label,high in (('high',True),('mobile',False)):
            original=(source/(f'{exercise}_v916_torso_'
                              f'{"high" if high else "mobile"}_qa.glb'))
            raw,report=solve(original.read_bytes(),exercise,high)
            file=target/f'{exercise}_v917_finger_{label}_qa.glb'
            file.write_bytes(raw)
            all_reports.append(report)
    report={
        'schema':'stk_haven_v917_finger_ik_artist_preview',
        'pilotCount':3,'variants':6,'fingerChannelsPerExercise':30,
        'catalogCount':229,
        'motionChanges':'finger_joint_only',
        'wristBarContactValidated':False,
        'fingertipBarSurfaceCertified':False,
        'approved':False,'enabled':False,
        'files':all_reports,
    }
    (target/'finger_kinematics_v917_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    options=parser.parse_args()
    print(json.dumps(build(options.input,options.output),indent=2))
