#!/usr/bin/env python3
"""STK Haven v9.18: conservative wrist orientation + measured finger/bar gaps.

Corrects *only* two hand-node rotations in six unpublished v9.17 GLBs.
Uses measured 30-fps phalanx-joint/bar distances, not fictional fingertip
contact. A joint position is NOT the skin surface or physical fingertip.
Existing 55-joint skin, 30 finger animation tracks, 8 morphs, IK wrist
positions, and every rigid equipment node/mesh are unchanged.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, SOURCE_SHA, EXERCISES, qmul, qnorm, motion
from exercise_surface_collision_v911 import _samplers, _sample
from animate_hand_grip_v917 import FINGERS, SIDES

FRAMES=121
FPS=30
MAX_ANGLE_DEG=18.
MAX_STEP_DEG=2.
MIN_RELATIVE_GAIN=.06
BAR_RADIUS=.019  # actual v9.8 cylinder shaft, not collar/plate radius
PENETRATION_GUARD=-.003  # joint point, not fingernail or skin clearance
MAX_MOBILE_BYTES=1400*1024
MAX_HIGH_BYTES=6*1024*1024
DIGITS=('index','middle','ring','pinky','thumb')

# Candidate local wrist-axis direction is calibrated against genuine CC0
# v9.17 pilot data. Neither its angles nor its results are certified by a
# biomechanics professional. Distinct sides account for mirrored rig axes.
DIRECTIONS={
    'ex_bench_press': {
       'l':((-1.07,.29,-.46),(-.71,.23,-.58)),
       'r':((-1.09,-.25,.44),(-.71,-.22,.58)),
    },
    'ex_barbell_row': {
       'l':((-1.01,.23,-.40),(-.76,.23,-.55)),
       'r':((-1.01,-.23,.40),(-.77,-.21,.54)),
    },
    'ex_squat': {
       # Constrained against the distal-joint shaft collider at 121 frames:
       # the stronger initial guess improved average gap but pushed ring
       # knuckles through the bar and widened thumb clearance.
       'l':((-.0256,.0006,-.3131),(.0821,-.0088,-.3031)),
       'r':((-.0285,-.0014,.3129),(.0774,.0186,.3039)),
    },
}


def rotation_vector_quaternion(vector):
    theta=math.sqrt(sum(v*v for v in vector))
    if not math.isfinite(theta):
        raise ValueError('Nonfinite wrist orientation')
    if theta<1e-9:
        return (0.,0.,0.,1.)
    scale=math.sin(theta/2.)/theta
    return tuple(v*scale for v in vector)+(math.cos(theta/2.),)


def degrees_between(a,b):
    dot=abs(sum(x*y for x,y in zip(a,b)))
    return math.degrees(2*math.acos(min(1.,max(0.,dot))))


def capped_vector(direction):
    length=math.sqrt(sum(x*x for x in direction))
    if not math.isfinite(length) or length<.1:
        raise ValueError('Unreliable pilot-specific palm orientation')
    k=min(1.,math.radians(MAX_ANGLE_DEG)/length)
    return tuple(x*k for x in direction)


def grip_pose(rest,exercise,side,seconds):
    if exercise not in DIRECTIONS or side not in SIDES:
        raise ValueError('Unrecognized finger grip variant')
    if not 0<=seconds<=4. or not math.isfinite(seconds):
        raise ValueError('Invalid keyframe time')
    if len(rest)!=4 or not .999<math.sqrt(sum(x*x for x in rest))<1.001:
        raise ValueError('Bad input wrist rest quaternion')
    neutral,peak=DIRECTIONS[exercise][side]
    # retarget.motion expects a normalized 0..1 phase, not seconds.
    # Keeping seconds here compressed a four-second grip into one second
    # and exceeded the 2-degree-per-key safety limit in CI #524.
    p=motion(seconds/4.)
    v=capped_vector(tuple(a*(1-p)+b*p for a,b in zip(neutral,peak)))
    pose=qnorm(qmul(rest,rotation_vector_quaternion(v)))
    if degrees_between(rest,pose)>MAX_ANGLE_DEG+.02:
        raise ValueError('Rotation leaves conservative wrist safety envelope')
    return pose


def verify_input(glb,exercise,high):
    if exercise not in EXERCISES:
        raise ValueError('Unrecognized exercise')
    doc=glb.doc;meta=doc.get('extras',{})
    if (meta.get('sourceSha256')!=SOURCE_SHA or
        meta.get('exerciseId')!=exercise or
        meta.get('handGripArtVersion')!=917 or
        meta.get('torsoContourArtVersion')!=916 or
        meta.get('torsoContourOutput')!=('authoring' if high else 'mobile') or
        meta.get('approved') is not False or
        meta.get('enabled') is not False or
        meta.get('masterExercisePilotVersion')!=910 or
        len(doc['skins'])!=1 or len(doc['skins'][0]['joints'])!=55 or
        len(doc['animations'])!=1 or
        len(doc['meshes'])!=(3 if exercise=='ex_bench_press' else 2) or
        len(doc['meshes'][0]['primitives'])!=12 or
        len(set(FINGERS).intersection(glb.by_name))!=30):
        raise ValueError('Only disabled original v9.17 master55 pilots accepted')
    if meta.get('gripContactCalibrationVersion') is not None:
        raise ValueError('Cannot stack wrist calibration')
    clip=doc['animations'][0]
    targets=[(c['target']['node'],c['target']['path'])
             for c in clip['channels']]
    if len(targets)!=len(set(targets)) or len(targets)<30 or any(
            (glb.by_name['hand_'+s],'rotation') in targets for s in SIDES):
        raise ValueError('Cannot overwrite existing wrist animation')
    if any(s.get('interpolation')!='LINEAR' for s in clip['samplers']):
        raise ValueError('Only LINEAR animation accepted')
    times=[x[0] for x in glb.accessor(clip['samplers'][0]['input'])]
    if len(times)!=41 or any(abs(t-i*.1)>1e-5
                             for i,t in enumerate(times)):
        raise ValueError('Expected 41 four-second keyframes')
    for s in SIDES:
        for digit in DIGITS:
            for segment in (1,2,3):
                if (glb.by_name[f'{digit}_0{segment}_{s}'],'rotation'
                    ) not in targets:
                    raise ValueError('Existing 30 finger tracks missing')
    return clip,times


def sampled_gap_metrics(glb):
    """Joint-center distances to bar-cylinder shell; not skin collision."""
    channels=_samplers(glb)
    radial_sum=0.
    largest=0.
    smallest=float('inf')
    n=0
    by_digit={digit:[] for digit in DIGITS}
    wrist_paths={}
    for k in range(FRAMES):
        seconds=k/FPS
        world,_,_=_sample(glb,channels,seconds)
        bar=world[glb.by_name['STK_EXERCISE_BAR']]
        if not all(math.isfinite(v) for v in bar):
            raise ValueError('Bad rigid bar motion')
        for side in SIDES:
            wrist=world[glb.by_name['hand_'+side]]
            wrist_paths[(k,side)]=wrist
            for digit in DIGITS:
                node=glb.by_name[f'{digit}_03_{side}']
                point=world[node]
                if not -1.1<=point[0]-bar[0]<=1.1:
                    raise ValueError('Finger joint outside bar shaft bounds')
                # The *distal joint origin* is a proxy; the fingertip extends
                # beyond it and the collider ignores skin and grip collars.
                radial=math.hypot(point[1]-bar[1],point[2]-bar[2])
                offset=radial-BAR_RADIUS
                if not math.isfinite(offset):
                    raise ValueError('Bad finger-to-bar distance')
                radial_sum+=max(0.,offset)
                largest=max(largest,offset)
                smallest=min(smallest,offset)
                by_digit[digit].append(offset)
                n+=1
    return {
        'frames':FRAMES,'fps':FPS,'sampledDistalJointCenters':n,
        'meanPositiveGapMeters':round(radial_sum/n,8),
        'worstPositiveGapMeters':round(largest,8),
        'closestSignedGapMeters':round(smallest,8),
        'meanGapByDigitMeters':{
          key:round(sum(max(0.,x) for x in values)/len(values),8)
          for key,values in by_digit.items()},
        'wristPaths':wrist_paths,
    }


def calibrate(raw,exercise,high=False):
    if len(raw)>(MAX_HIGH_BYTES if high else MAX_MOBILE_BYTES):
        raise ValueError('Source exceeds QA size budget')
    previous=GLB(raw,expected_sha=None)
    clip,times=verify_input(previous,exercise,high)
    old_metrics=sampled_gap_metrics(previous)
    current=GLB(raw,expected_sha=None)
    new_clip,new_times=verify_input(current,exercise,high)
    old_channel_count=len(new_clip['channels'])
    ticks=current.append(times,1,'SCALAR')
    max_step=0.
    angles={}
    for side in SIDES:
        hand=current.by_name['hand_'+side]
        rest=tuple(current.nodes[hand].get('rotation',(0,0,0,1)))
        frames=[grip_pose(rest,exercise,side,t) for t in new_times]
        angles[side]=round(max(degrees_between(rest,x) for x in frames),5)
        for a,b in zip(frames,frames[1:]):
            max_step=max(max_step,degrees_between(a,b))
        if degrees_between(frames[0],frames[-1])>1e-5:
            raise ValueError('Calibrated grip has an animation seam')
        outputs=current.append(frames,4,'VEC4')
        new_clip['samplers'].append({'input':ticks,'output':outputs,
                                     'interpolation':'LINEAR'})
        new_clip['channels'].append({
            'sampler':len(new_clip['samplers'])-1,
            'target':{'node':hand,'path':'rotation'},
        })
    if max_step>MAX_STEP_DEG or len(new_clip['channels'])!=old_channel_count+2:
        raise ValueError('Unsafe wrist rotation step or unexpected channels')
    better=sampled_gap_metrics(current)
    for frame in range(FRAMES):
        for side in SIDES:
            a=old_metrics['wristPaths'][(frame,side)]
            b=better['wristPaths'][(frame,side)]
            if math.dist(a,b)>1e-6:
                raise ValueError('Wrist target moved while adjusting orientation')
    start=old_metrics['meanPositiveGapMeters']
    end=better['meanPositiveGapMeters']
    improvement=1.-end/start
    if (improvement<MIN_RELATIVE_GAIN or
        better['closestSignedGapMeters']<PENETRATION_GUARD):
        raise ValueError('Calibration does not improve gap safely')
    for digit in DIGITS:
        if better['meanGapByDigitMeters'][digit] > (
             old_metrics['meanGapByDigitMeters'][digit]+.004):
            raise ValueError('Calibrated grip worsens digit: '+digit)
    # The worst gap remains far too large to call this contact. Explicitly
    # resist setting approved=True as a shortcut to green.
    if better['worstPositiveGapMeters']<.01:
        raise ValueError('Unexpected near-contact, inspect proxy instead')
    current.doc['extras']=dict(current.doc['extras'],
        gripContactCalibrationVersion=918,
        gripContactQAOnly=True,approved=False,enabled=False,
        fingerSurfaceToBarContactValidated=False,
        anatomicalHandProportionsApproved=False)
    built=current.bytes()
    if len(built)>(MAX_HIGH_BYTES if high else MAX_MOBILE_BYTES):
        raise ValueError('Calibrated GLB would exceed QA size budget')
    for metrics in (old_metrics,better):
        del metrics['wristPaths']
    report={
        'version':918,'exerciseId':exercise,'highResolution':high,
        'fingerDistalProxy':'last_glTF_finger_joint_not_fingertip',
        'barProxy':'X_axis_cylinder_radius_19mm_no_skin_friction',
        'baseline':old_metrics,'calibrated':better,
        'meanGapReductionPct':round(100*improvement,3),
        'maxWristOrientationDegrees':angles,
        'maxPerKeyframeWristAngularStepDegrees':round(max_step,6),
        'oldChannelCount':old_channel_count,'newChannelsAdded':2,
        'wristPositionsIdenticalAt121Frames':True,
        'remainingContactGapRequiresRigAndArtReview':True,
        'certifiedFingerSurfaceContact':False,
        'approved':False,'enabled':False,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'resultSha256':hashlib.sha256(built).hexdigest(),
        'outputBytes':len(built),
    }
    return built,report


def build(folder,output):
    origin=Path(folder);target=Path(output)
    target.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        for kind,high in (('mobile',False),('high',True)):
            source=origin/f'{exercise}_v917_finger_{kind}_qa.glb'
            result,report=calibrate(source.read_bytes(),exercise,high)
            (target/f'{exercise}_v918_contact_{kind}_qa.glb').write_bytes(result)
            reports.append(report)
    summary={
        'schema':'stk_master_55_v918_conservative_wrist_contact_qa',
        'catalogCount':229,'exercises':3,'assets':reports,
        'approved':False,'enabled':False,
        'deviceMeasured':False,
        'fingerPhysicalContactValidated':False,
    }
    (target/'contact_gap_v918_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    print(json.dumps(build(a.source,a.output),indent=2))
