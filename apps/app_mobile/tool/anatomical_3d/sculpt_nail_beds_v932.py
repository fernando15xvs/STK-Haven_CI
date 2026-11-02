#!/usr/bin/env python3
"""STK Haven v9.32: bounded distal nail-BED relief on REAL shared 55-bone skin.

Creates an optional subtle, smoothed convex nail-bed silhouette near the
existing ten distal phalanges in each of three quarantined GLBs. No separate
nail plate topology/UVs, cuticles, specialized material or photorealism.
Uses rig-derived axes and skin weights; never alters bones, weights, morphs,
topology, equipment or animation. Reverts to unchanged v9.31 geometry unless
orientation, size and full 241-pose morphed-skin contact guards pass.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import DIGITS,SIDES
from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals,_oriented
from optimize_finger_grip_v926 import _distal_vertices
from refine_fingertip_topology_v922 import _patch_view,MAX_MOBILE_BYTES
from retarget_cc0_glb import (
    EXERCISES,GLB,add,sub,mul,dot,norm,unit,cross
)
from sculpt_finger_knuckles_v930 import _joint_axes
from sculpt_palm_thenar_v924 import _reference,_triangles
from sculpt_finger_folds_v931 import _review_contact

MAX_BED_RELIEF_METERS=.00030
MIN_VERTEX_DELTA_METERS=.0000005
MAX_CONTACT_REGRESSION_METERS=.00065
SCALES=(1.,.5,.25,.125,.0625,.03125)
FRAME_COUNT=241
FPS=60


def nail_bed_profile(axial,lateral,dorsal,span):
    """Simple smooth raised bed within source mesh; NOT separate nail plate."""
    vals=(axial,lateral,dorsal,span)
    if any(not math.isfinite(x) for x in vals) or span<=0:
        raise ValueError('Nonfinite or invalid distal nail-bed coordinates')
    # Narrow longitudinal window with smooth taper and rounded side margins.
    axis_window=max(.006,min(.020,span*.43))
    forward=(axial-axis_window*.32)/axis_window
    if abs(forward)>2. or abs(lateral)>.025 or dorsal<-.004:
        return 0.
    length_taper=math.exp(-1.9*forward*forward)
    lateral_taper=math.exp(-1.6*(lateral/.010)**4)
    # The plane normal is from the master rig, not a hand-authored nail UV.
    dorsal_taper=max(0.,min(1.,(dorsal+.004)/.009))
    result=MAX_BED_RELIEF_METERS*length_taper*lateral_taper*dorsal_taper
    if not 0.<=result<=MAX_BED_RELIEF_METERS+1e-12:
        raise ValueError('Nail bed profile exceeded safe sculpt limit')
    return result


def _bed_vectors(glb,positions,joints,weights,skin):
    references={side:_reference(glb,side,skin) for side in SIDES}
    tips={}
    for side in SIDES:
        for digit in DIGITS:
            nodes,locations,axis=_joint_axes(glb,side,digit,skin)
            normal=references[side]['normal']
            projected=sub(normal,mul(axis,dot(normal,axis)))
            if norm(projected)<.08:
                raise ValueError('Degenerate projected nail direction')
            dorsal=unit(projected)
            width=unit(cross(axis,dorsal))
            palette=skin.index(nodes[2])
            span=norm(sub(locations[2],locations[1]))
            if not .003<span<.14:
                raise ValueError('Invalid distal phalanx length')
            tips[f'{digit}_{side}']=(locations[2],axis,dorsal,width,
                                    palette,span)
    # Source mesh is a single common skinned stream (no decals/overlays).
    vectors={}
    counts={key:0 for key in tips}
    for idx,p in enumerate(positions):
        proposals=[]
        for name,(origin,axis,dorsal,width,palette,span) in tips.items():
            influence=sum(float(w) for j,w in zip(
                joints[idx],weights[idx]) if int(j)==palette)
            if influence<.20:
                continue
            offset=sub(p,origin)
            axial=dot(offset,axis)
            lateral=dot(offset,width)
            height=dot(offset,dorsal)
            relief=nail_bed_profile(axial,lateral,height,span)
            relief*=max(0.,min(1.,(influence-.20)/.70))
            if relief>MIN_VERTEX_DELTA_METERS:
                proposals.append((relief,name,mul(dorsal,relief)))
        if proposals:
            magnitude,name,direction=max(proposals)
            if magnitude>MAX_BED_RELIEF_METERS+1e-9:
                raise ValueError('Excessive actual distal displacement')
            vectors[idx]=direction
            counts[name]+=1
    return vectors,counts


def sculpt(raw,exercise):
    glb,points,joints,weights,morphs,ibm,skin,_=_read_refined(
        raw,exercise)
    meta=glb.doc['extras']
    if (meta.get('fingerFoldSculptVersion')!=931 or
            meta.get('fingerKnuckleVolumeVersion')!=930 or
            meta.get('palmThumbRetopologyVersion')!=925 or
            meta.get('distalNailBedVersion') is not None or
            meta.get('approved') is not False or
            meta.get('enabled') is not False):
        raise ValueError('Only disabled v9.31 pilot can supply nail-bed QA')
    graph={name:copy.deepcopy(glb.doc[name]) for name in
           ('meshes','skins','nodes','animations','materials')}
    parts=glb.doc['meshes'][0]['primitives']
    attrs=parts[0]['attributes']
    normals=glb.accessor(attrs['NORMAL'])
    faces=_triangles(glb,len(points))
    if (len(morphs)!=8 or len(normals)!=len(points) or
            not 9843<len(faces)<=20000):
        raise ValueError('Unsupported shared atlas or morph stream')
    vectors,region_counts=_bed_vectors(glb,points,joints,weights,skin)
    # The distal mesh may simply have too few vertices for a nail relief.
    # That is NOT grounds to fabricate geometry; keep the original GLB.
    enough=(
        len(vectors)>=8 and
        any(region_counts[f'{digit}_{side}'] for digit in DIGITS
            for side in ('l',)) and
        any(region_counts[f'{digit}_{side}'] for digit in DIGITS
            for side in ('r',))
    )
    candidate=None
    scale=0.
    if enough:
        for factor in SCALES:
            pts=[add(p,mul(vectors[i],factor)) if i in vectors
                 else tuple(p) for i,p in enumerate(points)]
            if _oriented(points,pts,faces)==0:
                candidate=pts
                scale=factor
                break
    if candidate is None:
        candidate=[tuple(p) for p in points]
    sample={
        'samplesPerClip':FRAME_COUNT,'sampleRateHz':FPS,
        'passesSampledContactGuards':True,
        'introducedDeepPenetrationSamples':0,
        'largestWorsenedSignedMeters':0.,
        'largestMeanGapIncreaseMeters':0.,
        'regressions':[],
        'continuousCollisionCertified':False,
    }
    if scale:
        ids=_distal_vertices(glb,points,joints,weights,skin)
        sample=_review_contact(glb,points,candidate,morphs,joints,
                               weights,ibm,skin,ids)
    accepted=bool(scale and sample['passesSampledContactGuards']
                  and sample['largestWorsenedSignedMeters']<=
                  MAX_CONTACT_REGRESSION_METERS+1e-8
                  and sample['largestMeanGapIncreaseMeters']<=
                  MAX_CONTACT_REGRESSION_METERS+1e-8)
    changed=set()
    normals_changed=set()
    if accepted:
        changed={i for i in vectors if
                 norm(sub(candidate[i],points[i]))>
                 MIN_VERTEX_DELTA_METERS*.2}
        if len(changed)<8:
            accepted=False
    if accepted:
        normals_changed=set(changed)
        for a,b,c in faces:
            if a in changed or b in changed or c in changed:
                normals_changed.update((a,b,c))
        computed=_new_normals(candidate,normals,faces)
        revised=[tuple(computed[i]) if i in normals_changed
                 else tuple(n) for i,n in enumerate(normals)]
        _patch_view(glb,{
            attrs['POSITION']:candidate,
            attrs['NORMAL']:revised,
        })
    else:
        changed=set()
        normals_changed=set()
    meta.update({
        'distalNailBedVersion':932,
        'sourceFingerFoldSha256':hashlib.sha256(raw).hexdigest(),
        'nailBedSurfaceEditedVertices':len(changed),
        'nailBedFallbackToV931':not accepted,
        'nailPlateMeshComplete':False,
        'nailPlateUvComplete':False,
        'dorsalOrientationExpertVerified':False,
        'fullProfessionalHandSculptComplete':False,
        'contactIKComplete':False,'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,'approved':False,'enabled':False,
    })
    if any(glb.doc[name]!=saved for name,saved in graph.items()):
        raise ValueError('Nail surface edit illegally changed GLB structure')
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Nail bed QA result exceeds 1400KiB budget')
    decoded=GLB(output,expected_sha=None)
    dest_attrs=decoded.doc['meshes'][0]['primitives'][0]['attributes']
    actual=decoded.accessor(dest_attrs['POSITION'])
    if len(actual)!=len(points):
        raise ValueError('Changed count of common skinned mesh vertices')
    differing=sum(norm(sub(a,b))>MIN_VERTEX_DELTA_METERS*.2
                  for a,b in zip(actual,points))
    if accepted and differing<8:
        raise ValueError('Float32 export erased candidate nail relief')
    if not accepted and differing:
        raise ValueError('Rejected nail-bed candidate altered source mesh')
    return output,{
        'exerciseId':exercise,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'resultSha256':hashlib.sha256(output).hexdigest(),
        'surfaceVertices':len(points),'surfaceTriangles':len(faces),
        'candidateDistalVertices':len(vectors),
        'editedNailBedVertices':len(changed),
        'regionCandidates':region_counts,
        'candidateAccepted':accepted,'fallbackToV931':not accepted,
        'windingScale':scale,'normalsChanged':len(normals_changed),
        'maxActualDisplacementMeters':round(
            max(norm(sub(p,c)) for p,c in zip(points,candidate))
            if accepted else 0.,9),
        'sampledContactAudit':sample,
        'jointCount':55,'morphCount':8,'fingerChannelsPreserved':30,
        'UVComplete':False,'fullNailPlateComplete':False,
        'expertHandSculptApproved':False,'physicalDeviceVerified':False,
        'outputBytes':len(output),'approved':False,'enabled':False,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        data=(source/(exercise+'_v931_finger_fold_mobile_qa.glb')
              ).read_bytes()
        sculpted,info=sculpt(data,exercise)
        (output/(exercise+'_v932_nail_bed_mobile_qa.glb')
         ).write_bytes(sculpted)
        reports.append(info)
    summary={
        'schema':'stk_v932_real_skin_distal_nail_bed_relief_qa',
        'pilotCount':3,'catalogCount':229,'rigJoints':55,
        'framesPerClip':FRAME_COUNT,'maxReliefMeters':MAX_BED_RELIEF_METERS,
        'acceptedPilots':sum(x['candidateAccepted'] for x in reports),
        'fallbackPilots':sum(x['fallbackToV931'] for x in reports),
        'nailPlateMeshComplete':False,'nailUVComplete':False,
        'expertAnatomyApproved':False,'continuousCollisionCertified':False,
        'physicalDeviceVerified':False,'productionReady':False,
        'approved':False,'enabled':False,'pilots':reports,
    }
    (output/'nail_bed_v932_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    run=build(args.input,args.output)
    print(json.dumps({
        'schema':run['schema'],'accepted':run['acceptedPilots'],
        'fallback':run['fallbackPilots'],'approved':False,
    },indent=2))
