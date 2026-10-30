#!/usr/bin/env python3
"""STK Haven v9.30 — limited *actual mesh* finger knuckle sculpt, QA only.

Add mild dorsal/radial volume near rig-defined interphalangeal joints of the
three v9.29 pilot GLBs. Modify common glTF POSITION and NORMAL accessors in
the genuine 55-bone skinned atlas, not an overlay. Keep 8 corrective morph
streams, 30 animated finger channels, inverse bind matrices, topology and
equipment unchanged. NOT professional anatomy, nails, UV, physical grip IK,
triangle CCD, collision certification or publication approval.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from animate_hand_grip_v917 import DIGITS, SIDES
from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals, _oriented
from exercise_surface_collision_v911 import _samplers
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from retarget_cc0_glb import (
    GLB, EXERCISES, add, sub, mul, dot, norm, unit,
)
from sculpt_palm_thenar_v924 import _triangles
from review_fingertip_mesh_v919 import SHAFT_MIN_X, SHAFT_MAX_X, SHAFT_RADIUS
from exercise_surface_collision_v911 import (
    _sample, _skin_vertex, capped_cylinder_sdf,
)
from retarget_cc0_glb import qrot, qconj

MAX_KNUCKLE_DELTA_METERS=.00068
MIN_SCUlPT_METERS=.0000005
SCALES=(1.,.5,.25,.125,.0625,.03125,.015625)
MAX_CONTACT_DELTA_METERS=.0015
MAX_RADIUS_METERS=.023
MAX_FACES=20000
CHECK_FRAMES=(0,30,60,90,120,150,180,210,240)


def _joint_axes(glb,side,digit,skin):
    """Actual proximal/PIP/DIP bone reference, in neutral rig world frame."""
    labels=(f'{digit}_01_{side}',f'{digit}_02_{side}',
            f'{digit}_03_{side}')
    if any(x not in glb.by_name or glb.by_name[x] not in skin
           for x in labels):
        raise ValueError('Missing real finger bones: '+digit+'_'+side)
    joints=[glb.by_name[x] for x in labels]
    p=[glb.restpos[x] for x in joints]
    try:
        axis=unit(sub(p[2],p[0]))
    except ValueError as e:
        raise ValueError('Degenerate finger axis') from e
    if not .007<norm(sub(p[2],p[0]))<.19:
        raise ValueError('Outside plausible joint separation')
    return (joints,p,axis)


def _influence(joints,weights,palettes):
    wanted=set(palettes)
    return sum(float(weight) for joint,weight in zip(joints,weights)
               if int(joint) in wanted)


def _knuckle_delta(point,bones,weights,glb,skin,side,digit):
    """Small continuous radial bump on PIP and DIP; no false nail geometry."""
    (nodes,locations,axis)=_joint_axes(glb,side,digit,skin)
    wanted=[skin.index(node) for node in nodes]
    strength=_influence(bones,weights,wanted)
    if strength<.16:
        return (0.,0.,0.)
    # The middle and terminal phalanx joints are the two locations.
    # Their actual rest positions, not hand-sized proxies, set centers.
    options=[]
    for centre,band_scale in ((locations[1],1.),(locations[2],.66)):
        v=sub(point,centre)
        along=dot(v,axis)
        radial=sub(v,mul(axis,along))
        radius=norm(radial)
        if radius<.0006 or radius>MAX_RADIUS_METERS:
            continue
        local_span=max(.0045,min(.015,norm(sub(locations[2],locations[0]))*.30))
        axial=math.exp(-.5*(along/local_span)**2)
        radial_band=math.exp(-.5*((radius-.0075)/.0075)**2)
        weight=max(0.,min(1.,(strength-.16)/.74))
        # Shape the *existing skin* outwards. No translation of joint centers.
        amplitude=(MAX_KNUCKLE_DELTA_METERS*band_scale*axial*
                   radial_band*weight)
        if amplitude>.000000001:
            options.append((amplitude,mul(radial,1./radius)))
    if not options:
        return (0.,0.,0.)
    # Pick the stronger joint ridge so two nearby centers cannot overinflate.
    strength,direction=max(options,key=lambda x:x[0])
    return mul(direction,strength)


def _vectors(glb,points,joints,weights,skin):
    vectors={}
    assigned={f'{d}_{s}':set() for s in SIDES for d in DIGITS}
    axes={(side,digit):_joint_axes(glb,side,digit,skin)
          for side in SIDES for digit in DIGITS}
    # Nodes are validated above, and sampled skin influences select the
    # appropriate digit even where nearby fingertips visually overlap.
    for i,point in enumerate(points):
        ranked=[]
        for side in SIDES:
            for digit in DIGITS:
                if axes[(side,digit)] is None:
                    continue
                delta=_knuckle_delta(point,joints[i],weights[i],
                                     glb,skin,side,digit)
                ranked.append((norm(delta),side,digit,delta))
        amount,side,digit,delta=max(ranked)
        if amount>MIN_SCUlPT_METERS:
            vectors[i]=delta
            assigned[f'{digit}_{side}'].add(i)
    if len(vectors)<10:
        raise ValueError('Missing genuinely deformable knuckle vertices')
    if any(norm(delta)>MAX_KNUCKLE_DELTA_METERS+1e-8
           for delta in vectors.values()):
        raise ValueError('Knuckle displacement escaped geometric limit')
    if not all(any(assigned[f'{digit}_{side}'] for digit in DIGITS)
               for side in SIDES):
        raise ValueError('No visible bilateral finger joint relief')
    return vectors,assigned


def _contact_snapshot(glb,points,morphs,joints,weights,ibm,skin,ids,frame):
    """Measure every finger on morphed skin around animated finite bar."""
    channels=_samplers(glb)
    world,rot,activation=_sample(glb,channels,frame/60.)
    node=glb.by_name['STK_EXERCISE_BAR']
    origin=world[node]
    inverse=qconj(rot[node])
    by_vertex={}
    for i in sorted({v for group in ids.values() for v in group}):
        p=_skin_vertex(points[i],[target[i] for target in morphs],
                       weights[i],joints[i],ibm,
                       world,rot,skin,activation)
        local=qrot(inverse,tuple(p[k]-origin[k] for k in range(3)))
        by_vertex[i]=capped_cylinder_sdf(
            local,SHAFT_MIN_X,SHAFT_MAX_X,SHAFT_RADIUS)
    return {k:min(by_vertex[i] for i in members)
            for k,members in ids.items()}


def sculpt(raw,exercise):
    glb,p,j,w,morph,ibm,skin,_=_read_refined(raw,exercise)
    doc=glb.doc
    extra=doc['extras']
    if (extra.get('twoJointGripCandidateVersion')!=929 or
            extra.get('palmThumbRetopologyVersion')!=925 or
            extra.get('fingerKnuckleVolumeVersion') is not None or
            extra.get('approved') is not False or
            extra.get('enabled') is not False):
        raise ValueError('Require original unapproved v9.29 mobile QA GLB')
    before={k:copy.deepcopy(doc[k]) for k in
            ('nodes','skins','animations','materials','meshes')}
    parts=doc['meshes'][0]['primitives']
    attrs=parts[0]['attributes']
    normals=glb.accessor(attrs['NORMAL'])
    faces=_triangles(glb,len(p))
    if len(faces)>MAX_FACES or len(normals)!=len(p):
        raise ValueError('Unexpected mobile knuckle atlas size')
    vectors,groups=_vectors(glb,p,j,w,skin)
    selected=None
    for scale in SCALES:
        proposal=[add(point,mul(vectors[i],scale)) if i in vectors
                  else tuple(point) for i,point in enumerate(p)]
        if _oriented(p,proposal,faces)==0:
            selected=(proposal,scale)
            break
    if selected is None:
        raise ValueError('No non-inverting knuckle sculpt at limited scale')
    shaped,scale=selected
    moved={i for i in vectors
           if norm(sub(shaped[i],p[i]))>MIN_SCUlPT_METERS*.1}
    if len(moved)<10:
        raise ValueError('Knuckle volume has no measurable effect')
    changed_normals=set(moved)
    for a,b,c in faces:
        if a in moved or b in moved or c in moved:
            changed_normals.update((a,b,c))
    suggested=_new_normals(shaped,normals,faces)
    new_normals=[tuple(suggested[i]) if i in changed_normals
                 else tuple(n) for i,n in enumerate(normals)]

    # Deformed-skin signed-distance comparison of actual vertices at nine
    # distinct poses. Does NOT certify interiors of triangles or continuous
    # time. The SDF is 1-Lipschitz in point position, so <=1.5 mm worsening
    # is conservative for <=0.68 mm rest displacement plus skinning.
    ids={}
    for side in SIDES:
        for digit in DIGITS:
            palette=skin.index(glb.by_name[f'{digit}_03_{side}'])
            ranked=[
                (-(sum(float(weight) for node,weight in zip(j[i],w[i])
                       if int(node)==palette)),i)
                for i in range(len(p))
            ]
            close=[i for score,i in sorted(ranked) if -score>=.20][:28]
            if len(close)<6:
                raise ValueError('Missing distal skin contact evidence')
            ids[f'{digit}_{side}']=close
    largest_drop=0.
    for frame in CHECK_FRAMES:
        a=_contact_snapshot(glb,p,morph,j,w,ibm,skin,ids,frame)
        b=_contact_snapshot(glb,shaped,morph,j,w,ibm,skin,ids,frame)
        largest_drop=max(largest_drop,max(a[k]-b[k] for k in ids))
        if largest_drop>MAX_CONTACT_DELTA_METERS:
            raise ValueError('Knuckle sculpt regressed sampled grip by 1.5mm')

    _patch_view(glb,{
        attrs['POSITION']:shaped,
        attrs['NORMAL']:new_normals,
    })
    extra.update({
        'fingerKnuckleVolumeVersion':930,
        'sourceTwoJointCandidateSha256':hashlib.sha256(raw).hexdigest(),
        'realSkinnedKnuckleMeshModified':True,
        'knuckleProfessionalArtistApproved':False,
        'nailTopologyComplete':False,'fullHandRetopologyComplete':False,
        'continuousCollisionCertified':False,'gripIKComplete':False,
        'physicalDeviceVerified':False,
        'approved':False,'enabled':False,
    })
    if any(doc[k]!=v for k,v in before.items()):
        raise ValueError('Knuckle sculpt changed rig, tracks or materials')
    result=glb.bytes()
    if len(result)>MAX_MOBILE_BYTES:
        raise ValueError('Knuckle review exceeds 1400 KiB mobile cap')
    check=GLB(result,expected_sha=None)
    check_attrs=check.doc['meshes'][0]['primitives'][0]['attributes']
    output_vertices=check.accessor(check_attrs['POSITION'])
    if (len(output_vertices)!=len(p) or
            sum(norm(sub(a,b))>MIN_SCUlPT_METERS*.1
                for a,b in zip(output_vertices,p))<10):
        raise ValueError('Exported GLB lost real knuckle geometry changes')
    return result,{
        'exerciseId':exercise,'sourceVersion':929,
        'sourceSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(result).hexdigest(),
        'verticesEdited':len(moved),
        'knuckleGroupsWithEdits':sum(bool(v) for v in groups.values()),
        'editedRegionCounts':{k:len(v) for k,v in groups.items()},
        'triangleCount':len(faces),'sourceVertices':len(p),
        'maxDisplacementMeters':round(
            max(norm(sub(a,b)) for a,b in zip(shaped,p)),9),
        'scaleToKeepWinding':scale,
        'nearbyNormalsRecomputed':len(changed_normals),
        'sampledContactFrames':len(CHECK_FRAMES),
        'maxWorsenedSignedDistanceMeters':round(largest_drop,8),
        'rigJoints':55,'morphTargets':8,
        'changedMorphTargets':0,'editedFingerTracks':0,
        'professionalAnatomyCompleted':False,
        'contactIKCompleted':False,'deviceVerified':False,
        'assetBytes':len(result),
        'approved':False,'enabled':False,
    }


def build(source,output):
    source,output=Path(source),Path(output)
    output.mkdir(parents=True,exist_ok=True)
    reports=[]
    for exercise in EXERCISES:
        raw=(source/(exercise+'_v929_two_joint_grip_mobile_qa.glb'
                    )).read_bytes()
        model,info=sculpt(raw,exercise)
        (output/(exercise+'_v930_knuckle_volume_mobile_qa.glb')
         ).write_bytes(model)
        reports.append(info)
    summary={
        'schema':'stk_v930_skinned_knuckle_real_mesh_volume_qa',
        'catalogCount':229,'pilotCount':3,
        'rigJoints':55,'morphTargets':8,
        'sculptActuallyChangesMesh':True,
        'fullProfessionalHandAnatomyComplete':False,
        'expertHandReviewDone':False,'physicalDeviceVerified':False,
        'fullIKComplete':False,'continuousCollisionCertified':False,
        'approved':False,'enabled':False,'productionReady':False,
        'pilots':reports,
    }
    (output/'knuckle_surface_v930_report.json').write_text(
        json.dumps(summary,indent=2)+'\n',encoding='utf8')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    opts=parser.parse_args()
    print(json.dumps({'schema':build(opts.input,opts.output)['schema'],
                      'approved':False},indent=2))
