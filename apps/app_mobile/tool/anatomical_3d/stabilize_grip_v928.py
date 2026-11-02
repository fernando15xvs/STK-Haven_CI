#!/usr/bin/env python3
"""v9.28: fail-closed 60-Hz finger-grip track rollback on real master55 GLBs.

Keep v9.26 corrections only when the v9.27 sampled-skin comparison finds
improved gap without regressions. Recheck the combined motion. If unsafe,
restore ALL original glTF finger tracks. Not continuous collision certification,
artistic anatomy sign-off, finished IK, nor production media.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from retarget_cc0_glb import GLB, EXERCISES
from animate_hand_grip_v917 import SIDES, DIGITS
from exercise_surface_collision_v911 import _samplers
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
import audit_grip_temporal_v927 as audit927

MIN_MEAN_GAP_REDUCTION=.000015
SAMPLE_COUNT=241

def gate(stat, changed):
    if not changed:
        return False,'unchanged'
    fields=('sampledFrames','regressionFrames','introducedDeep',
            'deepBefore','deepAfter','baselineMeanPositiveGapMeters',
            'candidateMeanPositiveGapMeters')
    if not isinstance(stat,dict) or any(field not in stat for field in fields):
        raise ValueError('Incomplete measured contact evidence')
    if stat['sampledFrames']!=SAMPLE_COUNT:
        raise ValueError('Only v9.27 241-pose evidence accepted')
    before=stat['baselineMeanPositiveGapMeters']
    after=stat['candidateMeanPositiveGapMeters']
    if not all(isinstance(x,(int,float)) and math.isfinite(x) and x>=0
               for x in (before,after)):
        raise ValueError('Invalid surface gap values')
    if stat['regressionFrames']:
        return False,'measured_signed_distance_regression'
    if stat['introducedDeep'] or stat['deepAfter']>stat['deepBefore']:
        return False,'new_deep_penetration'
    if before-after<MIN_MEAN_GAP_REDUCTION:
        return False,'insufficient_mean_gap_improvement'
    return True,'improved_at_sampled_60hz_poses'


def _changed_digit_nodes(base,optimized):
    first,second=_samplers(base),_samplers(optimized)
    if first.keys()!=second.keys():
        raise ValueError('Changed clip channel keys')
    changed={}
    for side in SIDES:
        for digit in DIGITS:
            key=f'{digit}_{side}'
            joints=[base.by_name[f'{digit}_0{k}_{side}'] for k in (1,2,3)]
            actual=[node for node in joints
                    if first[(node,'rotation')]!=second[(node,'rotation')]]
            if len(actual)>1:
                raise ValueError('Multiple corrected joints per digit')
            changed[key]=actual[0] if actual else None
    return changed,first


def _restore(glb,source_tracks,nodes):
    if not nodes:
        return
    clip=glb.doc['animations'][0]
    accessors={}
    for channel in clip['channels']:
        key=channel['target']
        node=key['node']
        if node not in nodes or key['path']!='rotation':
            continue
        if node in accessors:
            raise ValueError('Duplicate finger track')
        accessors[node]=clip['samplers'][channel['sampler']]['output']
    if set(accessors)!=set(nodes) or len(set(accessors.values()))!=len(accessors):
        raise ValueError('Missing or shared finger rotation storage')
    _patch_view(glb,{
        accessor:source_tracks[(node,'rotation')]
        for node,accessor in accessors.items()
    })


def stabilize(before_raw,optimized_raw,exercise):
    if exercise not in EXERCISES or max(len(before_raw),len(optimized_raw))>MAX_MOBILE_BYTES:
        raise ValueError('Invalid disabled pilot or GLB size')
    original_report=audit927.review(before_raw,optimized_raw,exercise)
    base=GLB(before_raw,expected_sha=None)
    model=GLB(optimized_raw,expected_sha=None)
    if model.doc['extras'].get('gripTemporalRollbackVersion') is not None:
        raise ValueError('Cannot run rollback on previously filtered model')
    digit_nodes,source_tracks=_changed_digit_nodes(base,model)
    modified={digit:node for digit,node in digit_nodes.items()
              if node is not None}
    if len(modified)!=original_report['changedFingerTracks']:
        raise ValueError('Inconsistent source joint correction count')
    kept={}
    reasons={}
    for digit,node in digit_nodes.items():
        ok,reason=gate(original_report['fingerResults'][digit],node is not None)
        reasons[digit]=reason
        if ok:
            kept[digit]=node
    _restore(model,source_tracks,{
        node for digit,node in modified.items() if digit not in kept})
    meta=model.doc['extras']
    meta.update({
        'gripTemporalRollbackVersion':928,
        'sourceBaselineSha256':hashlib.sha256(before_raw).hexdigest(),
        'sourceOptimizedSha256':hashlib.sha256(optimized_raw).hexdigest(),
        'fingerCorrectedTracks':len(kept),
        'rollbackCandidateOnly':True,
        'fullContactIKComplete':False,
        'continuousCollisionCertified':False,
        'professionalAnatomyApproved':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    final_bytes=model.bytes()
    final=audit927.review(before_raw,final_bytes,exercise)
    passed=final['no60HzSampleRegressions'] and all(
        stat['introducedDeep']==0 and stat['deepAfter']<=stat['deepBefore']
        for stat in final['fingerResults'].values())
    if passed:
        passed=all(
            final['fingerResults'][digit]['baselineMeanPositiveGapMeters']-
            final['fingerResults'][digit]['candidateMeanPositiveGapMeters']>=
            MIN_MEAN_GAP_REDUCTION for digit in kept)
    fallback=False
    if not passed:
        # Cross-digit skinning interactions may invalidate individual gates.
        # Never relax the threshold: restore the entire v9.25 finger motion.
        _restore(model,source_tracks,set(modified.values()))
        kept={}
        fallback=True
        meta['fingerCorrectedTracks']=0
        final_bytes=model.bytes()
        final=audit927.review(before_raw,final_bytes,exercise)
        if (final['changedFingerTracks']!=0 or
                not final['no60HzSampleRegressions'] or
                any(x['introducedDeep'] for x in final['fingerResults'].values())):
            raise ValueError('Full-clip finger rollback did not restore baseline')
    if final['changedFingerTracks']!=len(kept):
        raise ValueError('Final clip metadata and edited tracks disagree')
    if len(final_bytes)>MAX_MOBILE_BYTES:
        raise ValueError('Final GLB exceeded mobile QA budget')
    decoded=GLB(final_bytes,expected_sha=None)
    for key in ('nodes','skins','meshes','materials','animations'):
        if decoded.doc[key]!=base.doc[key]:
            raise ValueError('Unexpected geometry, rig or channel-graph edit')
    report={
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(before_raw).hexdigest(),
        'optimizedSha256':hashlib.sha256(optimized_raw).hexdigest(),
        'resultSha256':hashlib.sha256(final_bytes).hexdigest(),
        'initialChangedTracks':len(modified),
        'keptTracks':len(kept),
        'revertedTracks':len(modified)-len(kept),
        'fullFallbackToOriginalClip':fallback,
        'perDigit':{
            digit:{
                'decision':('kept' if digit in kept else
                            'reverted' if digit in modified else 'unchanged'),
                'initialReason':reasons[digit]
            } for digit in digit_nodes
        },
        'initial60HzRegressionFrames':original_report['regressionFramesTotal'],
        'final60HzRegressionFrames':final['regressionFramesTotal'],
        'finalIntroducedDeepFrames':sum(
            x['introducedDeep'] for x in final['fingerResults'].values()),
        'finalNoObserved60HzRegression':final['no60HzSampleRegressions'],
        'framesEvaluated':SAMPLE_COUNT,'rigJoints':55,'morphTargets':8,
        'continuousCollisionCertified':False,
        'fullContactIKComplete':False,'physicallyVerified':False,
        'approved':False,'enabled':False,
    }
    return final_bytes,report


def build(baseline_dir,optimized_dir,output_dir):
    baseline_dir,optimized_dir,output_dir=map(Path,(
        baseline_dir,optimized_dir,output_dir))
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        baseline=(baseline_dir/(exercise+'_v925_palm_web_topology_mobile_qa.glb')
                  ).read_bytes()
        candidate=(optimized_dir/(exercise+'_v926_grip_optimized_mobile_qa.glb')
                   ).read_bytes()
        raw,report=stabilize(baseline,candidate,exercise)
        (output_dir/(exercise+'_v928_grip_stabilized_mobile_qa.glb')
         ).write_bytes(raw)
        reports.append(report)
    result={
        'schema':'stk_v928_60hz_fail_closed_grip_candidate_qa',
        'catalogCount':229,'pilotCount':3,'sourceVersion':926,
        'keptJointCorrections':sum(x['keptTracks'] for x in reports),
        'revertedJointCorrections':sum(x['revertedTracks'] for x in reports),
        'clipFallbacks':sum(x['fullFallbackToOriginalClip'] for x in reports),
        'all241SamplesNoObservedRegression':all(
            x['finalNoObserved60HzRegression'] for x in reports),
        'continuousCollisionCertified':False,'fullContactIKComplete':False,
        'physicalDeviceVerified':False,'productionReady':False,
        'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output_dir/'grip_temporal_rollback_v928_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--baseline',required=True,type=Path)
    cli.add_argument('--candidate',required=True,type=Path)
    cli.add_argument('--output',required=True,type=Path)
    args=cli.parse_args()
    print(json.dumps(build(args.baseline,args.candidate,args.output),indent=2))
