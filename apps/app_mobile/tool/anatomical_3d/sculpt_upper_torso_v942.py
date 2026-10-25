#!/usr/bin/env python3
"""STK Haven v9.42: bounded upper-body silhouette detail, QA only.

Builds upon the real skinned v9.41 torso surface. Reuses the actual eleven
CC0 muscle-region primitive masks to refine six existing upper-body regions;
within pectoralis, guides upper (clavicular) vs lower (sternocostal) envelopes.
Does NOT create independent anatomical muscle meshes, verify attachments,
modify catalog media or confer professional anatomy/biomechanics approval.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals, _oriented
from build_master_surface_v7 import region_votes, weighted_profile, smoothstep
from refine_fingertip_topology_v922 import _patch_view, MAX_MOBILE_BYTES
from retarget_cc0_glb import GLB, EXERCISES, add, mul, norm, sub
from sculpt_lower_leg_anatomy_v940 import _cap_normals, FOLD_SCALE
from sculpt_palm_thenar_v924 import _triangles

REGIONS = (
    'pectoralis_major', 'anterior_deltoid', 'posterior_deltoid',
    'latissimus_dorsi', 'rhomboids', 'middle_trapezius',
)
REGION_RELIEF_METERS = {
    'pectoralis_major': .00100,
    'anterior_deltoid': .00085,
    'posterior_deltoid': .00085,
    'latissimus_dorsi': .00072,
    'rhomboids': .00055,
    'middle_trapezius': .00055,
}
MAX_ADDED_DISPLACEMENT_METERS = .00120
MIN_SIDE_X = .012


def chest_subregion_weights(local_y):
    """Artist guidance only, not anatomically distinct glTF materials."""
    upper = smoothstep((local_y + .18) / .63)
    return upper, 1. - upper


def _propose(points, normals, votes):
    if len(points) != len(normals) or any(
            len(rows) != len(points) for rows in votes.values()):
        raise ValueError('Upper torso mask/mesh length mismatch')
    if not set(REGIONS).issubset(votes):
        raise ValueError('Missing upper torso atlas regions')
    profiles = {(region,side): weighted_profile(points,votes[region],side)
                for region in REGIONS for side in ('l','r')}
    hits = {region:{'l':0,'r':0} for region in REGIONS}
    chest = {'clavicular_upper':0, 'sternocostal_lower':0}
    proposed = []
    for i,(p,n) in enumerate(zip(points,normals)):
        if abs(p[0]) <= MIN_SIDE_X:
            proposed.append(0.)
            continue
        side = 'l' if p[0] > 0 else 'r'
        delta = 0.
        for region in REGIONS:
            membership = smoothstep((votes[region][i] - .07)/.65)
            if membership < 1e-5:
                continue
            center,radius = profiles[region,side]
            local = tuple((p[k] - center[k])/radius[k] for k in range(3))
            radius2 = sum(v*v for v in local)
            envelope = math.exp(-.85*radius2)
            if region == 'pectoralis_major':
                upper,lower = chest_subregion_weights(local[1])
                shape = .9*upper + .76*lower
            elif region in ('anterior_deltoid','posterior_deltoid'):
                shape = .74+.26*math.exp(-1.3*(local[1]+.14)**2)
            elif region == 'latissimus_dorsi':
                shape = .74+.26*smoothstep((-local[1]+1.)/2.)
            else:
                shape = .82+.18*math.exp(-1.9*local[0]*local[0])
            front = region in ('pectoralis_major','anterior_deltoid')
            facing = smoothstep(
                ((n[2] if front else -n[2]) + .18)/.55)
            contribution = (REGION_RELIEF_METERS[region] *
                membership * envelope * shape * facing)
            delta += contribution
            if contribution > .000015:
                hits[region][side] += 1
                if region == 'pectoralis_major':
                    if upper > .15:
                        chest['clavicular_upper'] += 1
                    if lower > .15:
                        chest['sternocostal_lower'] += 1
        proposed.append(min(MAX_ADDED_DISPLACEMENT_METERS,delta) *
                        smoothstep((abs(p[0])-MIN_SIDE_X)/.04))
    if max(proposed, default=0) < .000005:
        raise ValueError('Upper-body geometry not modified')
    if any(hits[k][side]<3 for k in REGIONS for side in ('l','r')):
        raise ValueError('Missing real bilateral upper-body region surface')
    if any(v<3 for v in chest.values()):
        raise ValueError('Pectoralis upper/lower region was not differentiated')
    return proposed,hits,chest


def sculpt(raw,exercise):
    if exercise not in EXERCISES or len(raw)>MAX_MOBILE_BYTES:
        raise ValueError('Invalid or oversized upper-body QA source')
    glb,points,joints,weights,morphs,_ibm,skin,_ = (
        _read_refined(raw,exercise))
    meta=glb.doc['extras']
    if (meta.get('torsoVolumeVersion')!=941 or
        meta.get('upperTorsoContourVersion') is not None or
        meta.get('approved') is not False or
        meta.get('enabled') is not False or len(morphs)!=8 or len(skin)!=55):
        raise ValueError('Requires disabled v9.41 master exercise GLB')
    doc=glb.doc
    preserved={key:copy.deepcopy(doc[key]) for key in (
        'nodes','skins','animations','meshes','materials')}
    primitives=doc['meshes'][0]['primitives']
    attrs=primitives[0]['attributes']
    if len(primitives)!=12 or any(p['attributes']!=attrs for p in primitives):
        raise ValueError('Wrong 12-region shared-skin atlas')
    normals=glb.accessor(attrs['NORMAL'])
    votes,_faces=region_votes(glb,len(points))
    proposed,hits,chest=_propose(points,normals,votes)
    faces=_triangles(glb,len(points))
    chosen=None
    for scale in FOLD_SCALE:
        updated=[add(p,mul(n,offset*scale))
                 for p,n,offset in zip(points,normals,proposed)]
        if _oriented(points,updated,faces)==0:
            chosen=(updated,scale)
            break
    if chosen is None:
        raise ValueError('Upper torso sculpt caused triangle inversions')
    revised,scale=chosen
    mask=[v>1e-8 for v in proposed]
    new_normals=_new_normals(revised,normals,faces)
    refined,max_angle=_cap_normals(normals,new_normals,mask)
    biggest=max(norm(sub(a,b)) for a,b in zip(points,revised))
    if biggest>MAX_ADDED_DISPLACEMENT_METERS+1e-8:
        raise ValueError('Upper torso exceeded displacement envelope')
    _patch_view(glb,{
        attrs['POSITION']:revised,attrs['NORMAL']:refined,
    })
    doc['accessors'][attrs['POSITION']]['min']=[
        min(p[k] for p in revised) for k in range(3)]
    doc['accessors'][attrs['POSITION']]['max']=[
        max(p[k] for p in revised) for k in range(3)]
    for key,original in preserved.items():
        if doc[key]!=original:
            raise ValueError('Upper torso changed protected skinned scene')
    meta.update({
        'upperTorsoContourVersion':942,
        'sourceTorsoVolumeSha256':hashlib.sha256(raw).hexdigest(),
        'upperTorsoArtistGuidedNotAnatomistValidated':True,
        'chestClavicularSternocostalArtGuidesOnly':True,
        'biomechanicsCertified':False,
        'professionalAnatomyComplete':False,
        'physicalDeviceBenchmarked':False,
        'approved':False,'enabled':False,
    })
    data=glb.bytes()
    if len(data)>MAX_MOBILE_BYTES:
        raise ValueError('Upper-body GLB grew beyond mobile QA limit')
    parsed=GLB(data,expected_sha=None)
    for key,original in preserved.items():
        if parsed.doc[key]!=original:
            raise ValueError('Roundtrip changed protected glTF metadata')
    output_positions=parsed.accessor(
        parsed.doc['meshes'][0]['primitives'][0]['attributes']['POSITION'])
    if max(norm(sub(a,b)) for a,b in zip(revised,output_positions))>.00001:
        raise ValueError('Roundtrip modified upper-body geometry')
    return data,{
        'exerciseId':exercise,
        'inputSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(data).hexdigest(),
        'jointCount':55,'morphTargets':8,'regionCount':12,
        'editedSkinnedBodyVertices':sum(mask),
        'upperTorsoRegionSamples':hits,
        'pectoralisArtGuideSamples':chest,
        'maxAddedDisplacementMeters':round(biggest,8),
        'maxNormalChangeDegrees':round(max_angle,5),
        'foldPreventionScale':scale,
        'invertedTriangles':0,
        'animationSkinEquipmentPreserved':True,
        'professionallyReviewed':False,
        'physicalDeviceValidated':False,
        'bytes':len(data),
        'approved':False,'enabled':False,
    }


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    rows=[]
    for exercise in EXERCISES:
        raw=(source_dir/(exercise+'_v941_torso_volume_mobile_qa.glb')
             ).read_bytes()
        payload,row=sculpt(raw,exercise)
        (output_dir/(exercise+'_v942_upper_torso_mobile_qa.glb')
         ).write_bytes(payload)
        rows.append(row)
    result={
        'schema':'stk_v942_bilateral_upper_torso_art_surface_qa',
        'catalogCount':229,'pilotCount':3,
        'refinedRegions':list(REGIONS),
        'chestArtGuides':['clavicular_upper','sternocostal_lower'],
        'rigJoints':55,'correctiveMorphs':8,
        'productionReady':False,
        'anatomyProfessionallyApproved':False,
        'physicalDeviceValidated':False,
        'approved':False,'enabled':False,
        'pilots':rows,
    }
    (output_dir/'upper_torso_v942_report.json').write_text(
        json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    r=build(args.input,args.output)
    print(json.dumps({'schema':r['schema'],
                      'pilots':r['pilotCount'],
                      'approved':False},indent=2))
