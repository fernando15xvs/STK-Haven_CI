#!/usr/bin/env python3
"""STK Haven v9.31: real skinned interphalangeal fold relief, QA only.

Procedurally sculpt small PIP/DIP transition folds into the existing 55-joint
mobile GLB skin, preserving indexed topology, original 8 morphs and 30 finger
animation tracks. Evaluate all 241 poses of actual morphed/skinned skin against
the moving bar. Fail closed to original v9.30 geometry if collision/proximity
guards fail; never publish or mark the clip approved.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import SIDES, DIGITS
from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals, _oriented
from exercise_surface_collision_v911 import _samplers
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from retarget_cc0_glb import GLB, EXERCISES, add, sub, mul, dot, norm
from sculpt_palm_thenar_v924 import _triangles
from sculpt_finger_knuckles_v930 import _joint_axes
from optimize_finger_grip_v926 import _distal_vertices
from audit_grip_temporal_v927 import _measure, DEEP_METERS

MAX_FOLD_METERS = .00038
MIN_VISIBLE_DELTA_METERS = .0000005
MAX_SAMPLED_PROXIMITY_REGRESSION_METERS = .00065
MAX_SAMPLED_MEAN_GAP_REGRESSION_METERS = .00065
SCALES = (1., .5, .25, .125, .0625, .03125)
FRAME_COUNT = 241
FPS = 60


def fold_profile(axial, radius, bone_span):
    """Bounded grooved ridge in metres; no photorealism is asserted."""
    if not all(math.isfinite(x) for x in (axial, radius, bone_span)):
        raise ValueError('Nonfinite anatomical fold coordinates')
    if radius < 0 or bone_span <= 0:
        raise ValueError('Invalid anatomical fold radius')
    width = min(.009, max(.0045, bone_span*.29))
    valley = math.exp(-.5*(axial/width)**2)
    ridge = math.exp(-.5*((abs(axial)-width*1.45)/
                            (width*.68))**2)
    radial = math.exp(-.5*((radius-.009)/.014)**2)
    return radial*(-.00032*valley+.000085*ridge)


def _real_fold_vectors(glb, points, joints, weights, skin):
    refs={}
    for side in SIDES:
        for digit in DIGITS:
            nodes,locations,axis=_joint_axes(glb,side,digit,skin)
            palettes={skin.index(n) for n in nodes}
            span=norm(sub(locations[2],locations[0]))
            if span < .007:
                raise ValueError('Collapsed real phalanx rig')
            refs[(side,digit)]=(locations,axis,palettes,span)
    moved={}
    per={f'{digit}_{side}':set() for side in SIDES for digit in DIGITS}
    for i,point in enumerate(points):
        candidates=[]
        for (side,digit),(locations,axis,palettes,span) in refs.items():
            strength=sum(float(w) for joint,w in zip(joints[i],weights[i])
                         if int(joint) in palettes)
            if strength < .12:
                continue
            best=(0.,(0.,0.,0.))
            # Local PIP and DIP transitions, not arbitrary whole-hand waves.
            for center in (locations[1],locations[2]):
                rel=sub(point,center)
                axial=dot(rel,axis)
                radial=sub(rel,mul(axis,axial))
                radius=norm(radial)
                if radius<.0006 or radius>.027 or abs(axial)>.035:
                    continue
                profile=fold_profile(axial,radius,span)
                amplitude=profile*max(0.,min(1.,(strength-.12)/.64))
                if abs(amplitude)>abs(best[0]):
                    best=(amplitude,mul(radial,1./radius))
            if best[0]:
                displacement=mul(best[1],best[0])
                candidates.append((norm(displacement),side,digit,displacement))
        if not candidates:
            continue
        magnitude,side,digit,delta=max(candidates)
        if magnitude>MIN_VISIBLE_DELTA_METERS:
            if magnitude>MAX_FOLD_METERS+1e-9:
                raise ValueError('Crease escaped 0.38 mm envelope')
            moved[i]=delta
            per[f'{digit}_{side}'].add(i)
    if len(moved)<12 or any(
            not any(per[f'{digit}_{side}'] for digit in DIGITS)
            for side in SIDES):
        raise ValueError('No measurable bilateral PIP/DIP surface vertices')
    return moved,per


def _review_contact(glb, original, sculpted, morphs, joints, weights,
                    ibm, skin, ids):
    """Real skinned vertices and morphs at all 241 frames, no shortcuts."""
    channels=_samplers(glb)
    before=(original,morphs,weights,joints,ibm,skin)
    after=(sculpted,morphs,weights,joints,ibm,skin)
    worse=0.
    increase_in_gap=0.
    new_deep=0
    most_regressed=[]
    for frame in range(FRAME_COUNT):
        time=frame/FPS
        a=_measure(glb,channels,ids,before,time)
        b=_measure(glb,channels,ids,after,time)
        for digit in ids:
            a_min,a_gap=a[digit]
            b_min,b_gap=b[digit]
            worsening=max(0.,a_min-b_min)
            gap_regression=max(0.,b_gap-a_gap)
            worse=max(worse,worsening)
            increase_in_gap=max(increase_in_gap,gap_regression)
            if a_min>=DEEP_METERS and b_min<DEEP_METERS:
                new_deep+=1
            if (worsening>MAX_SAMPLED_PROXIMITY_REGRESSION_METERS or
                    gap_regression>MAX_SAMPLED_MEAN_GAP_REGRESSION_METERS):
                if len(most_regressed)<15:
                    most_regressed.append({'frame':frame,'digit':digit,
                                           'newMinSignedMeters':b_min,
                                           'oldMinSignedMeters':a_min})
    return {
        'samplesPerClip':FRAME_COUNT,
        'sampleRateHz':FPS,
        'largestWorsenedSignedMeters':round(worse,8),
        'largestMeanGapIncreaseMeters':round(increase_in_gap,8),
        'introducedDeepPenetrationSamples':new_deep,
        'regressions':most_regressed,
        'passesSampledContactGuards':not new_deep and not most_regressed,
        'continuousCollisionCertified':False,
    }


def sculpt(raw, exercise):
    glb,points,joints,weights,morphs,ibm,skin,_=_read_refined(raw,exercise)
    extras=glb.doc['extras']
    if (extras.get('fingerKnuckleVolumeVersion')!=930 or
            extras.get('twoJointGripCandidateVersion')!=929 or
            extras.get('palmThumbRetopologyVersion')!=925 or
            extras.get('fingerFoldSculptVersion') is not None or
            extras.get('approved') is not False or
            extras.get('enabled') is not False):
        raise ValueError('Only original unapproved v9.30 55-bone pilot accepted')
    source_graph={key:copy.deepcopy(glb.doc[key]) for key in
                  ('skins','nodes','meshes','animations','materials')}
    attrs=glb.doc['meshes'][0]['primitives'][0]['attributes']
    normals=glb.accessor(attrs['NORMAL'])
    if len(normals)!=len(points) or len(morphs)!=8:
        raise ValueError('Missing full skinned mesh/8 corrective morphs')
    faces=_triangles(glb,len(points))
    if not 9843<len(faces)<=20000:
        raise ValueError('Unsupported bounded mobile pilot atlas')
    directions,groups=_real_fold_vectors(
        glb,points,joints,weights,skin)
    selected=None
    for scale in SCALES:
        proposal=[add(p,mul(directions[i],scale)) if i in directions
                  else tuple(p) for i,p in enumerate(points)]
        if _oriented(points,proposal,faces)==0:
            selected=(proposal,scale)
            break
    if selected is None:
        # Preserve the fully validated v9.30 geometry, never write a mesh
        # with inverted or degenerate triangle winding.
        proposal=[tuple(p) for p in points]
        factor=0.
    else:
        proposal,factor=selected
    edits={i for i in directions
           if norm(sub(proposal[i],points[i]))>MIN_VISIBLE_DELTA_METERS*.2}
    if factor and len(edits)<10:
        factor=0.
        proposal=[tuple(p) for p in points]
        edits=set()
    contact={
        'samplesPerClip':FRAME_COUNT,'sampleRateHz':FPS,
        'largestWorsenedSignedMeters':0.,
        'largestMeanGapIncreaseMeters':0.,
        'introducedDeepPenetrationSamples':0,'regressions':[],
        'passesSampledContactGuards':True,
        'continuousCollisionCertified':False,
    }
    if factor:
        ids=_distal_vertices(glb,points,joints,weights,skin)
        contact=_review_contact(glb,points,proposal,morphs,
                                joints,weights,ibm,skin,ids)
    accepted=bool(factor and contact['passesSampledContactGuards'])
    changed_normals=set()
    if accepted:
        changed_normals=set(edits)
        for a,b,c in faces:
            if a in edits or b in edits or c in edits:
                changed_normals.update((a,b,c))
        recomputed=_new_normals(proposal,normals,faces)
        shading=[tuple(recomputed[i]) if i in changed_normals
                 else tuple(n) for i,n in enumerate(normals)]
        _patch_view(glb,{
            attrs['POSITION']:proposal,
            attrs['NORMAL']:shading,
        })
    extras.update({
        'fingerFoldSculptVersion':931,
        'sourceKnuckleSculptSha256':hashlib.sha256(raw).hexdigest(),
        'realSkinnedFoldVerticesChanged':len(edits) if accepted else 0,
        'foldFallbackToV930':not accepted,
        'fullProfessionalHandAnatomyComplete':False,
        'fingerNailMeshComplete':False,'fullContactIKComplete':False,
        'continuousCollisionCertified':False,
        'expertBiomechanicalReviewComplete':False,
        'physicalDeviceVerified':False,'approved':False,'enabled':False,
    })
    if any(glb.doc[key]!=value for key,value in source_graph.items()):
        raise ValueError('Fold sculpt changed original clip/skin/atlas graph')
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Sculpt exceeded quarantined 1400 KiB GLB cap')
    exported=GLB(output,expected_sha=None)
    eattrs=exported.doc['meshes'][0]['primitives'][0]['attributes']
    actual=exported.accessor(eattrs['POSITION'])
    if len(actual)!=len(points):
        raise ValueError('GLB serialization lost shared skin vertices')
    measured=sum(norm(sub(a,b))>MIN_VISIBLE_DELTA_METERS*.2
                 for a,b in zip(actual,points))
    if accepted and measured<10:
        raise ValueError('Fold mesh vanished after float32 export')
    if not accepted and measured:
        raise ValueError('Fail-closed fold baseline was unexpectedly modified')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'candidateFoldVertices':len(directions),
        'editedFoldVertices':len(edits) if accepted else 0,
        'bilateralCandidateGroups':{
            digit:len(rows) for digit,rows in groups.items()},
        'accepted':accepted,'fallbackToOriginalKnuckleMesh':not accepted,
        'safeWindingFactor':factor,
        'actualMaxDeltaMeters':round(
            max(norm(sub(a,b)) for a,b in zip(points,proposal))
            if accepted else 0.,9),
        'normalVerticesRecomputed':len(changed_normals),
        'skinJointCount':55,'morphTargets':8,'unchangedFingerTracks':30,
        'triangleCount':len(faces),'surfaceVertices':len(points),
        'contactAudit60Hz':contact,
        'professionalAnatomyComplete':False,
        'physicalDeviceVerified':False,
        'fullIKComplete':False,
        'outputBytes':len(output),'approved':False,'enabled':False,
    }


def build(source_dir, output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        input_file=source_dir/(exercise+'_v930_knuckle_volume_mobile_qa.glb')
        candidate,report=sculpt(input_file.read_bytes(),exercise)
        (output_dir/(exercise+'_v931_finger_fold_mobile_qa.glb')
         ).write_bytes(candidate)
        reports.append(report)
    summary={
        'schema':'stk_v931_actual_skinned_joint_fold_60hz_qa',
        'catalogCount':229,'pilotCount':3,'rigJoints':55,
        'maxFoldDeltaMeters':MAX_FOLD_METERS,'framesAt60Hz':FRAME_COUNT,
        'acceptedFoldPilots':sum(x['accepted'] for x in reports),
        'fallbackPilots':sum(x['fallbackToOriginalKnuckleMesh']
                             for x in reports),
        'allOriginalSkinAndAnimationPreserved':True,
        'fullProfessionalHandComplete':False,
        'triangleContinuousCollisionCertified':False,
        'expertAnatomyReviewed':False,'physicalDeviceVerified':False,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':reports,
    }
    (output_dir/'finger_fold_surface_v931_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    result=build(args.input,args.output)
    print(json.dumps({
        'schema':result['schema'],'pilots':result['pilotCount'],
        'accepted':result['acceptedFoldPilots'],
        'approved':False,'enabled':False,
    },indent=2))
