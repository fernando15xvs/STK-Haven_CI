#!/usr/bin/env python3
"""STK Haven v9.43 — dynamic 60 Hz QA comparing v9.41 and v9.42.

Samples the ACTUAL GLB POSITION + 8 morph targets + 55-joint skin for all
three 4-second exercise clips. Catches unbounded skinned deformation and
unexpected regressions around the rotated bar/bench. The sampled comparison
is NOT continuous collision detection, biomechanical proof or visual signoff.
Never modifies production media.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from exercise_surface_collision_v911 import (
    _bar_sdf, _equipment_boxes, _sample, _samplers, _skin_vertex, box_sdf,
)
from retarget_cc0_glb import EXERCISES, qconj, qrot
from sculpt_upper_torso_v942 import MAX_ADDED_DISPLACEMENT_METERS

FPS = 60
FRAMES = 241
MAX_CHANGED_SAMPLES = 160
MAX_UNCHANGED_SAMPLES = 32
MAX_SKINNED_DISPLACEMENT_METERS = MAX_ADDED_DISPLACEMENT_METERS + .00004
MAX_SDF_REGRESSION_METERS = MAX_SKINNED_DISPLACEMENT_METERS + .00001


def _evenly(items, limit):
    """Deterministic vertex sampling, always including the last index."""
    if len(items) <= limit:
        return list(items)
    return [items[(i * (len(items)-1)) // (limit-1)]
            for i in range(limit)]


def _select(original, revised):
    if len(original) != len(revised):
        raise ValueError('QA comparisons require identical mesh topology')
    changed = [i for i,(a,b) in enumerate(zip(original,revised))
               if math.dist(a,b) > 1e-8]
    unchanged = [i for i,(a,b) in enumerate(zip(original,revised))
                 if math.dist(a,b) <= 1e-8]
    if len(changed)<12 or len(unchanged)<12:
        raise ValueError('Upper-body sculpt changed too much or too little')
    left = [i for i in changed if original[i][0]>=0]
    right = [i for i in changed if original[i][0]<0]
    if min(len(left),len(right)) < 6:
        raise ValueError('Missing genuinely bilateral skinned surface')
    max_index = max(changed,key=lambda i:math.dist(original[i],revised[i]))
    half = MAX_CHANGED_SAMPLES//2
    selected = sorted(set(_evenly(left,half)+_evenly(right,half)+
                          [max_index]+_evenly(unchanged,MAX_UNCHANGED_SAMPLES)))
    return selected, changed, unchanged, max_index


def review(previous:bytes, candidate:bytes, exercise:str):
    if exercise not in EXERCISES:
        raise ValueError('Unrecognized master exercise')
    a,p,j,w,m,ibm,skin,_ = _read_refined(previous,exercise)
    b,q,j2,w2,m2,ibm2,skin2,_ = _read_refined(candidate,exercise)
    meta=a.doc['extras']
    updated=b.doc['extras']
    if (meta.get('torsoVolumeVersion') != 941 or
        updated.get('upperTorsoContourVersion') != 942 or
        updated.get('sourceTorsoVolumeSha256') !=
            hashlib.sha256(previous).hexdigest() or
        any(x.get('approved') is not False or x.get('enabled') is not False
            for x in (meta,updated))):
        raise ValueError('Only SHA-pinned unapproved v9.41/v9.42 pair allowed')
    for field in ('nodes','skins','animations','meshes','materials'):
        if a.doc[field] != b.doc[field]:
            raise ValueError('Skinned scene mutated protected '+field)
    if (j!=j2 or w!=w2 or m!=m2 or ibm!=ibm2 or skin!=skin2 or
        len(skin)!=55 or len(m)!=8):
        raise ValueError('Joint, morph or weight streams were modified')
    chosen,changed,unchanged,largest=_select(p,q)
    max_bind=max(math.dist(x,y) for x,y in zip(p,q))
    if max_bind > MAX_ADDED_DISPLACEMENT_METERS + .00001:
        raise ValueError('Bind-pose displacement escaped sculpt envelope')
    tracks=_samplers(a)
    bar_node=a.by_name['STK_EXERCISE_BAR']
    boxes=_equipment_boxes(a)
    if bool(boxes)!=(exercise=='ex_bench_press'):
        raise ValueError('Expected exercise-specific rigid bench')
    stable_indices=set(chosen).intersection(unchanged)
    peak=0.
    bar_change=0.
    bench_change=0.
    max_stable=0.
    peak_frame=0
    samples=0
    first=None
    last=None
    smallest_bar_before=float('inf')
    smallest_bar_after=float('inf')
    for frame in range(FRAMES):
        seconds=frame/FPS
        world,rot,activation=_sample(a,tracks,seconds)
        bar=world[bar_node]
        inverse_bar=qconj(rot[bar_node])
        pose_snapshot=[]
        for index in chosen:
            morph=[shape[index] for shape in m]
            old=_skin_vertex(p[index],morph,w[index],j[index],
                             ibm,world,rot,skin,activation)
            new=_skin_vertex(q[index],morph,w[index],j[index],
                             ibm,world,rot,skin,activation)
            dist=math.dist(old,new)
            if not math.isfinite(dist) or dist>MAX_SKINNED_DISPLACEMENT_METERS:
                raise ValueError('Excess skinned 60Hz drift: '+
                                 str((exercise,frame,index,dist)))
            samples+=1
            if dist>peak:
                peak,peak_frame=dist,frame
            if index in stable_indices:
                max_stable=max(max_stable,dist)
                if dist>2e-6:
                    raise ValueError('Unaffected atlas vertex was modified')
            if index==largest:
                pose_snapshot.append(old)
                pose_snapshot.append(new)
            old_local=qrot(inverse_bar,tuple(old[k]-bar[k] for k in range(3)))
            new_local=qrot(inverse_bar,tuple(new[k]-bar[k] for k in range(3)))
            old_bar=_bar_sdf(old_local,(0.,0.,0.))
            new_bar=_bar_sdf(new_local,(0.,0.,0.))
            if not all(math.isfinite(v) for v in (old_bar,new_bar)):
                raise ValueError('Nonfinite bar proximity')
            if abs(new_bar-old_bar)>MAX_SDF_REGRESSION_METERS:
                raise ValueError('Bar proximity moved beyond vertex envelope')
            bar_change=max(bar_change,abs(new_bar-old_bar))
            smallest_bar_before=min(smallest_bar_before,old_bar)
            smallest_bar_after=min(smallest_bar_after,new_bar)
            for lower,upper in boxes:
                old_bench=box_sdf(old,lower,upper)
                new_bench=box_sdf(new,lower,upper)
                if abs(new_bench-old_bench)>MAX_SDF_REGRESSION_METERS:
                    raise ValueError('Bench proximity moved beyond envelope')
                bench_change=max(bench_change,
                                 abs(new_bench-old_bench))
        if len(pose_snapshot)!=2:
            raise ValueError('Maximum-displacement vertex not sampled')
        if frame==0:first=pose_snapshot
        if frame==FRAMES-1:last=pose_snapshot
    if samples != FRAMES*len(chosen) or peak<1e-7:
        raise ValueError('Incomplete animated skinning coverage')
    # Do not require already-imperfect pilot loops to be perfect.
    # Ensure new geometry does not increase existing seam error by > envelope.
    prior_seam=math.dist(first[0],last[0])
    after_seam=math.dist(first[1],last[1])
    if after_seam>prior_seam+2*MAX_SKINNED_DISPLACEMENT_METERS:
        raise ValueError('Upper torso introduced loop-seam displacement')
    return {
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(previous).hexdigest(),
        'candidateSha256':hashlib.sha256(candidate).hexdigest(),
        'sampleRateHz':FPS,'frames':FRAMES,'evaluatedSkinVertices':len(chosen),
        'skinningEvaluations':samples*2,
        'sourceBindVertexCount':len(p),
        'changedBindVertices':len(changed),
        'unchangedBindVertices':len(unchanged),
        'maxBindDisplacementMeters':round(max_bind,8),
        'maxAnimatedDisplacementMeters':round(peak,8),
        'frameAtMaxAnimatedDisplacement':peak_frame,
        'maxUnchangedSurfaceDriftMeters':round(max_stable,9),
        'maxBarProximityChangeMeters':round(bar_change,8),
        'minimumBarSdfBeforeMeters':round(smallest_bar_before,7),
        'minimumBarSdfAfterMeters':round(smallest_bar_after,7),
        'maxBenchProximityChangeMeters':round(bench_change,8),
        'maxSampledLoopSeamIncreaseMeters':round(after_seam-prior_seam,8),
        'skinningJointCount':55,'morphTargetCount':8,
        'rigAndEquipmentUnchanged':True,
        'maxDisplacementEnvelopeEnforced':True,
        'fullSurfaceCollisionCertified':False,
        'continuousCollisionCertified':False,
        'professionalBiomechanicsApproved':False,
        'physicalDeviceReviewed':False,
        'approved':False,'enabled':False,
    }


def build(source_dir, candidate_dir, output_dir):
    source_dir,candidate_dir,output_dir=map(
        Path,(source_dir,candidate_dir,output_dir))
    output_dir.mkdir(parents=True,exist_ok=True)
    rows=[]
    for exercise in EXERCISES:
        previous=(source_dir/(exercise+
            '_v941_torso_volume_mobile_qa.glb')).read_bytes()
        candidate=(candidate_dir/(exercise+
            '_v942_upper_torso_mobile_qa.glb')).read_bytes()
        rows.append(review(previous,candidate,exercise))
    result={
        'schema':'stk_v943_skinned_upper_torso_60hz_motion_proximity_qa',
        'catalogCount':229,'pilotCount':3,
        'sampleRateHz':FPS,'framesPerPilot':FRAMES,
        'noProductionChanges':True,
        'physicalDeviceBenchmarked':False,
        'continuousCollisionCertified':False,
        'biomechanicsProfessionallyApproved':False,
        'approved':False,'enabled':False,
        'pilots':rows,
    }
    (output_dir/'dynamic_torso_v943_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    opt=parser.parse_args()
    result=build(opt.source,opt.candidate,opt.output)
    print(json.dumps({'schema':result['schema'],
                      'pilots':result['pilotCount'],
                      'approved':False},indent=2))
