#!/usr/bin/env python3
"""STK Haven v9.29: TWO-joint candidate finger/bar contact search, offline QA.

Discrete limited two-joint inverse-kinematics-style search over the actual
30 tracked phalanges of the 55-bone glTF pilot. Scores real skinned/morphed
distal skin and finite animated bar at 1, 2 and 3 s. Checks the resulting
whole two-hand clip at 60 Hz (241 samples). On ANY disallowed cross-finger
or between-key regression, reverts every correction to original v9.25.

This is a bounded experimental solver, NOT clinically validated ROM,
continuous-time triangle CCD, contact forces or production-ready art.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import itertools
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import DIGITS, SIDES, quaternion_distance_degrees
from audit_finger_contact_bounds_v923 import _read_refined
from exercise_surface_collision_v911 import _samplers
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from retarget_cc0_glb import GLB, EXERCISES
import optimize_finger_grip_v926 as grip926
import audit_grip_temporal_v927 as audit927

SEARCH_DEGREES=(-1.5,1.5)
MAX_JOINTS_PER_FINGER=2
MAX_JOINT_DEGREES=1.5
MIN_OBJECTIVE_GAIN=1e-9
MIN_MEAN_GAP_REDUCTION=.000015
FRAMES=241


def gate(base, changed, has_two_joints):
    """Fail closed on observed whole-clip skin/bar regressions."""
    if not has_two_joints:
        return False,'no_two_joint_improvement'
    required=('frames','regressionFrames','introducedDeep',
              'deepBefore','deepAfter','gapBefore','gapAfter')
    if not isinstance(changed,dict) or any(k not in changed for k in required):
        raise ValueError('Incomplete 60 Hz skin sample evidence')
    if changed['frames']!=FRAMES:
        raise ValueError('Requires all 241 sampled exercise poses')
    if changed['regressionFrames']:
        return False,'worse_sampled_signed_distance'
    if changed['introducedDeep'] or changed['deepAfter']>changed['deepBefore']:
        return False,'more_deep_penetration'
    if not all(math.isfinite(changed[k]) and changed[k]>=0
               for k in ('gapBefore','gapAfter')):
        raise ValueError('Nonfinite distance to bar')
    if changed['gapBefore']-changed['gapAfter']<MIN_MEAN_GAP_REDUCTION:
        return False,'insufficient_mean_surface_approach'
    return True,'improved_at_sampled_60hz_poses'


def _search(glb,channels,selected,mesh,bar):
    """Test two phalanges per finger, never edit wrist, elbow or body."""
    corrections={}
    reasons={}
    for side in SIDES:
        for digit in DIGITS:
            label=f'{digit}_{side}'
            ids=selected[label]
            baseline=grip926._evaluate(glb,channels,corrections,ids,mesh,bar)
            baseline_score=sum(item[0] for item in baseline)
            best=(baseline_score,None,baseline)
            tried=0
            feasible=0
            for segment1,segment2 in itertools.combinations((1,2,3),2):
                n1=glb.by_name[f'{digit}_0{segment1}_{side}']
                n2=glb.by_name[f'{digit}_0{segment2}_{side}']
                for a,b in itertools.product(SEARCH_DEGREES,repeat=2):
                    tried+=1
                    proposed={**corrections,n1:a,n2:b}
                    viable=True
                    for node,degrees in ((n1,a),(n2,b)):
                        values=channels.get((node,'rotation'))
                        if values is None:
                            raise ValueError('Missing original phalange track')
                        try:
                            candidate=grip926.corrected_track(values,degrees)
                        except ValueError:
                            viable=False
                            break
                        rest=tuple(glb.nodes[node].get(
                            'rotation',(0.,0.,0.,1.)))
                        if max(quaternion_distance_degrees(rest,q)
                               for q in candidate)>grip926.MAX_REST_DEGREES+.02:
                            viable=False
                            break
                    if not viable:
                        continue
                    feasible+=1
                    measure=grip926._evaluate(
                        glb,channels,proposed,ids,mesh,bar)
                    if any(new[1]<old[1]-grip926.MAX_DEEPER_METERS
                           for old,new in zip(baseline,measure)):
                        continue
                    score=sum(item[0] for item in measure)
                    if score<best[0]-MIN_OBJECTIVE_GAIN:
                        best=(score,((n1,a),(n2,b)),measure)
            if best[1] is not None:
                for node,degrees in best[1]:
                    corrections[node]=degrees
            reasons[label]={
                'considered':tried,'romFeasible':feasible,
                'selectedTwoJoints':best[1] is not None,
                'sourceObjective':round(baseline_score,10),
                'optimizedObjective':round(best[0],10),
                'jointNames':[
                    glb.nodes[node]['name'] for node,_ in (best[1] or ())
                ],
                'degrees':[degrees for _,degrees in (best[1] or ())],
                'optimizesThreeKeyPosesOnly':True,
            }
    return corrections,reasons


def _rotation_accessors(glb,nodes):
    out={}
    clip=glb.doc['animations'][0]
    for channel in clip['channels']:
        target=channel['target']
        if target['path']!='rotation' or target['node'] not in nodes:
            continue
        node=target['node']
        if node in out:
            raise ValueError('Duplicate rotation track')
        sampler=clip['samplers'][channel['sampler']]
        if sampler.get('interpolation')!='LINEAR':
            raise ValueError('Cannot edit nonlinear finger rotation')
        out[node]=sampler['output']
    if set(out)!=set(nodes) or len(set(out.values()))!=len(nodes):
        raise ValueError('Missing or shared two-joint rotation accessor')
    return out


def audit_pair(glb,channels,altered,selected,mesh):
    """241 real skinned poses for ALL fingers, including between keyframes."""
    if set(channels)!=set(altered):
        raise ValueError('Mismatched glTF channel set')
    records={key:{
        'frames':FRAMES,'regressionFrames':0,
        'betweenKeyRegressionFrames':0,'introducedDeep':0,
        'deepBefore':0,'deepAfter':0,
        'gapBefore':0.,'gapAfter':0.,
        'minimumBefore':float('inf'),'minimumAfter':float('inf'),
    } for key in selected}
    for frame in range(FRAMES):
        seconds=frame/60.
        a=audit927._measure(glb,channels,selected,mesh,seconds)
        b=audit927._measure(glb,altered,selected,mesh,seconds)
        for key in records:
            stat=records[key]
            old,old_gap=a[key]
            now,new_gap=b[key]
            if audit927.regression(old,now):
                stat['regressionFrames']+=1
                if frame%6:
                    stat['betweenKeyRegressionFrames']+=1
            stat['deepBefore']+=int(old<audit927.DEEP_METERS)
            stat['deepAfter']+=int(now<audit927.DEEP_METERS)
            stat['introducedDeep']+=int(
                old>=audit927.DEEP_METERS and now<audit927.DEEP_METERS)
            stat['gapBefore']+=old_gap
            stat['gapAfter']+=new_gap
            stat['minimumBefore']=min(stat['minimumBefore'],old)
            stat['minimumAfter']=min(stat['minimumAfter'],now)
    for stat in records.values():
        for k in ('gapBefore','gapAfter'):
            stat[k]=round(stat[k]/FRAMES,9)
        for k in ('minimumBefore','minimumAfter'):
            stat[k]=round(stat[k],7)
    return records


def optimize(raw,exercise):
    glb,p,j,w,morph,ibm,skin,_=_read_refined(raw,exercise)
    doc=glb.doc
    meta=doc['extras']
    if (meta.get('palmThumbRetopologyVersion')!=925 or
            meta.get('palmThumbSculptVersion')!=924 or
            meta.get('fingerContactOptimizerVersion') is not None or
            meta.get('gripTemporalRollbackVersion') is not None or
            meta.get('twoJointGripCandidateVersion') is not None or
            meta.get('approved') is not False or
            meta.get('enabled') is not False):
        raise ValueError('Only trusted disabled original v9.25 GLB accepted')
    original={key:copy.deepcopy(doc[key]) for key in
              ('meshes','skins','nodes','materials','animations')}
    channels=_samplers(glb)
    finger_nodes={
        glb.by_name[f'{digit}_0{k}_{side}']
        for side in SIDES for digit in DIGITS for k in (1,2,3)
    }
    digit_tracks=sum(
        key[1]=='rotation' and key[0] in finger_nodes
        for key in channels)
    if digit_tracks!=30:
        raise ValueError('All thirty original finger rotations required')
    selected=grip926._distal_vertices(glb,p,j,w,skin)
    if len(selected)!=10:
        raise ValueError('Bilateral skin coverage required')
    mesh=(p,morph,w,j,ibm,skin)
    bar=glb.by_name['STK_EXERCISE_BAR']
    search,choices=_search(glb,channels,selected,mesh,bar)
    if len(search)>20:
        raise ValueError('Two-joint finger search escaped maximum')
    altered=dict(channels)
    for node,degrees in search.items():
        if abs(degrees)>MAX_JOINT_DEGREES:
            raise ValueError('Exceeded local joint flexion constraint')
        altered[(node,'rotation')]=grip926.corrected_track(
            channels[(node,'rotation')],degrees)
    candidates=audit_pair(glb,channels,altered,selected,mesh)
    accepted_per_digit={}
    for label,decision in choices.items():
        accepted_per_digit[label]=gate(
            None,candidates[label],decision['selectedTwoJoints'])
    initially_changed=sum(decision['selectedTwoJoints']
                          for decision in choices.values())
    # Cross-finger skin weights can make changes interact. Do not keep a
    # partly rejected state: revert every proposed correction if ANY sampled
    # pose or selected digit fails the independent/global 60 Hz guards.
    global_pass=all(
        stat['regressionFrames']==0 and stat['introducedDeep']==0 and
        stat['deepAfter']<=stat['deepBefore']
        for stat in candidates.values())
    digits_pass=all(accepted_per_digit[label][0]
                    for label,decision in choices.items()
                    if decision['selectedTwoJoints'])
    keep=bool(search) and global_pass and digits_pass
    patches={}
    if keep:
        outputs=_rotation_accessors(glb,set(search))
        patches={
            outputs[node]:altered[(node,'rotation')]
            for node in search
        }
        if len(patches)!=len(search):
            raise ValueError('Unexpected shared two-joint skin channels')
        _patch_view(glb,patches)
    meta.update({
        'twoJointGripCandidateVersion':929,
        'sourcePalmTopologySha256':hashlib.sha256(raw).hexdigest(),
        'twoJointCandidateOnly':True,
        'twoJointCorrectionsProposed':len(search),
        'twoJointCorrectionsKept':len(patches),
        'twoJointFullFallback':not keep and bool(search),
        'jointROMExpertCertified':False,'fullContactIKComplete':False,
        'continuousCollisionCertified':False,
        'physicallyValidated':False,'approved':False,'enabled':False,
    })
    if any(doc[key]!=original[key] for key in original):
        raise ValueError('Two-joint solver changed rig or clip graph')
    result=glb.bytes()
    if len(result)>MAX_MOBILE_BYTES:
        raise ValueError('Two-joint QA GLB too large for mobile')
    check=GLB(result,expected_sha=None)
    check_channels=_samplers(check)
    if set(check_channels)!=set(channels):
        raise ValueError('Changed clip target set after serialization')
    for key,before in channels.items():
        now=check_channels[key]
        if key[0] not in search or not keep:
            if now!=before:
                raise ValueError('Unexpected mutation of source animation')
        elif (now[0]!=before[0] or now[-1]!=before[-1]
              or len(now)!=len(before)):
            raise ValueError('Broken finger loop seam')
    # Real float32 export may differ marginally from in-memory probes.
    # Recheck all real 60-Hz samples, and FAIL CLOSED to original on any
    # regression introduced by output rounding or cross-digit deformation.
    if keep:
        exported=audit_pair(check,channels,check_channels,selected,mesh)
        if any(not gate(None,exported[label],choices[label]['selectedTwoJoints'])[0]
               for label in selected if choices[label]['selectedTwoJoints']) or any(
                stat['regressionFrames'] or stat['introducedDeep'] or
                stat['deepAfter']>stat['deepBefore']
                for stat in exported.values()):
            # Real output failed => emit unmodified original motion, never
            # publish the candidate from this pass.
            glb2=GLB(raw,expected_sha=None)
            glb2.doc['extras'].update(meta)
            glb2.doc['extras']['twoJointCorrectionsKept']=0
            glb2.doc['extras']['twoJointFullFallback']=True
            result=glb2.bytes()
            keep=False
    report={
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'resultSha256':hashlib.sha256(result).hexdigest(),
        'surfaceVertices':len(p),'rigJoints':55,'morphTargets':8,
        'fingerTracks':30,'fingersAnalyzed':10,
        'twoJointCandidatesSelected':initially_changed,
        'proposedModifiedTracks':len(search),
        'keptModifiedTracks':len(search) if keep else 0,
        'fullFallback':not keep and bool(search),
        'jointSearch':choices,
        '60HzObservedContact':candidates,
        'gateDecisions':{
            key:{'kept':bool(keep and choices[key]['selectedTwoJoints']),
                 'reason':(
                     accepted_per_digit[key][1] if keep else
                     'global_sampled_pose_fallback' if bool(search) else
                     accepted_per_digit[key][1])}
            for key in choices},
        'sampleRateHz':60,'sampledFrames':FRAMES,
        'anatomicalIKComplete':False,
        'triangleContinuousCollisionCertified':False,
        'independentExpertReview':False,'physicalDeviceVerified':False,
        'outputBytes':len(result),
        'approved':False,'enabled':False,
    }
    return result,report


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source_dir/(exercise+'_v925_palm_web_topology_mobile_qa.glb')
             ).read_bytes()
        model,report=optimize(raw,exercise)
        (output_dir/(exercise+'_v929_two_joint_grip_mobile_qa.glb')
         ).write_bytes(model)
        reports.append(report)
    summary={
        'schema':'stk_v929_two_joint_55_bone_skin_contact_search_qa',
        'catalogCount':229,'pilotCount':3,'rigJoints':55,
        'fingersPerPilot':10,'originalFingerTracks':30,
        'maxJointTracksPerFinger':2,'maxExtraJointDegrees':1.5,
        'sampleRateHz':60,'sampledFrames':241,
        'keptCorrections':sum(p['keptModifiedTracks'] for p in reports),
        'candidateFallbackCount':sum(p['fullFallback'] for p in reports),
        'expertAnatomyApproved':False,'fullContactIKComplete':False,
        'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,'productionReady':False,
        'pilots':reports,
    }
    (output_dir/'two_joint_grip_v929_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    print(json.dumps({'schema':build(args.input,args.output)['schema'],
                      'enabled':False,'approved':False},indent=2))
