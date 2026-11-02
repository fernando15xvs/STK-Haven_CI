#!/usr/bin/env python3
"""STK Haven v9.40: actual posterior lower-leg sculpt on skinned mobile GLBs.

Adds bounded calf contour fields for medial/lateral gastrocnemius and soleus
to the original 55-bone CC0 body. Write ONLY shared body POSITION/NORMAL
accessors. The twelve muscle atlas primitives, 8 corrective morphs, joints,
UV nail/cuticle overlays, exercise equipment and all animation data remain.
These are anatomical ART directions, not validated muscles, attachment points
or medical/biomechanics evidence. Only 3 disabled mobile QA pilots.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from audit_finger_contact_bounds_v923 import _read_refined
from bake_master_detail_v915 import _new_normals,_oriented
from sculpt_palm_thenar_v924 import _triangles
from refine_fingertip_topology_v922 import _patch_view,MAX_MOBILE_BYTES
from retarget_cc0_glb import (
    GLB,EXERCISES,add,sub,mul,dot,norm,unit,
)

RELIEF_METERS=.00165
MAX_NORMAL_CHANGE_DEGREES=9.
FOLD_SCALE=(1.,.60,.35,.18,.10)
MIN_CALF_INFLUENCE=.20
MAX_CONTACT_SKIN_DISPLACEMENT_METERS=.00165
HEADS=('gastrocnemius_medialis','gastrocnemius_lateralis','soleus')


def _bone_frames(glb,skin):
    frames={}
    for side in ('l','r'):
        calf=glb.by_name.get('calf_'+side)
        ankle=glb.by_name.get('foot_'+side)
        if calf is None or ankle is None or calf not in skin:
            raise ValueError('Missing genuine lower-leg bone for '+side)
        knee=glb.restpos[calf]
        foot=glb.restpos[ankle]
        shaft=sub(foot,knee)
        length=norm(shaft)
        if not .16<length<.75:
            raise ValueError('Unnatural or collapsed lower leg bone')
        frames[side]=(knee,unit(shaft),length,skin.index(calf))
    return frames


def _gauss(value,centre,sigma):
    return math.exp(-.5*((value-centre)/sigma)**2)


def _propose(points,normals,joints,weights,frames):
    """Bilateral three-muscle fields, attached to actual calf skin weights."""
    proposed=[0.]*len(points)
    contribution={s:{h:0 for h in HEADS} for s in ('l','r')}
    for i,(p,n,ids,ww) in enumerate(zip(points,normals,joints,weights)):
        posterior=max(0.,min(1.,(-n[2]-.08)/.55))
        if posterior<.04:continue
        best=0.
        owner=None
        for side,(origin,axis,length,palette) in frames.items():
            influence=sum(float(w) for j,w in zip(ids,ww)
                          if int(j)==palette)
            if influence<MIN_CALF_INFLUENCE:continue
            delta=sub(p,origin)
            t=dot(delta,axis)/length
            if not .055<t<.95:continue
            shaft=add(origin,mul(axis,t*length))
            side_direction=1. if side=='l' else -1.
            x=(p[0]-shaft[0])*side_direction
            fields={
                'gastrocnemius_medialis':
                  _gauss(t,.32,.15)*_gauss(x,-.025,.055),
                'gastrocnemius_lateralis':
                  .82*_gauss(t,.37,.16)*_gauss(x,.025,.055),
                'soleus':
                  .68*_gauss(t,.66,.18)*_gauss(x,.00,.07),
            }
            for label,magnitude in fields.items():
                f=RELIEF_METERS*posterior*min(1.,influence)*magnitude
                if f>best:
                    best=f
                    owner=(side,label)
        if owner and best>1e-8:
            proposed[i]=best
            contribution[owner[0]][owner[1]]+=1
    return proposed,contribution


def _cap_normals(old,new,edited):
    """Retain old normal on unaffected mesh, bound artist-shading changes."""
    output=[]
    max_angle=0.
    limit=math.radians(MAX_NORMAL_CHANGE_DEGREES)
    for i,(a,b) in enumerate(zip(old,new)):
        if not edited[i]:
            output.append(tuple(a))
            continue
        a=unit(a)
        b=unit(b)
        cosine=max(-1.,min(1.,dot(a,b)))
        angle=math.acos(cosine)
        if angle>limit:
            ratio=limit/angle
            v=unit(add(mul(a,1.-ratio),mul(b,ratio)))
        else:
            v=b
        final=math.acos(max(-1.,min(1.,dot(a,v))))
        if final>limit+1e-6:
            raise ValueError('Calf shading exceeded angle limit')
        output.append(v)
        max_angle=max(max_angle,final)
    return output,math.degrees(max_angle)


def sculpt(raw,exercise):
    if exercise not in EXERCISES or len(raw)>MAX_MOBILE_BYTES:
        raise ValueError('Invalid master exercise QA input')
    glb,points,joints,weights,morphs,ibm,skin,_=_read_refined(raw,exercise)
    metadata=glb.doc['extras']
    if (metadata.get('cuticleFoldGeometryVersion')!=939 or
        metadata.get('lowerLegContourVersion') is not None or
        metadata.get('approved') is not False or
        metadata.get('enabled') is not False or
        len(morphs)!=8 or len(glb.doc['skins'][0]['joints'])!=55):
        raise ValueError('Expected inactive complete v9.39 anatomical pilot')
    doc=glb.doc
    preserved={key:copy.deepcopy(doc[key]) for key in (
        'nodes','skins','animations','meshes','materials'
    )}
    base=doc['meshes'][0]['primitives']
    attrs=base[0]['attributes']
    if any(p['attributes']!=attrs for p in base):
        raise ValueError('Body atlas must share original 55-bone attributes')
    normals=glb.accessor(attrs['NORMAL'])
    if len(normals)!=len(points):
        raise ValueError('Corrupt master skinned body normals')
    frames=_bone_frames(glb,skin)
    targets,region_hits=_propose(
        points,normals,joints,weights,frames)
    if max(targets,default=0.)<=1e-7:
        raise ValueError('Missing both calves in the anatomical skin surface')
    faces=_triangles(glb,len(points))
    selection=None
    for scale in FOLD_SCALE:
        pos=[add(p,mul(n,delta*scale))
             for p,n,delta in zip(points,normals,targets)]
        if _oriented(points,pos,faces)==0:
            selection=(pos,scale)
            break
    if selection is None:
        raise ValueError('Posterior lower-leg contour inverted a body face')
    revised,scale=selection
    raw_normals=_new_normals(revised,normals,faces)
    edit_mask=[d>1e-8 for d in targets]
    smoothed,largest_angle=_cap_normals(
        normals,raw_normals,edit_mask)
    biggest=max(norm(sub(p,q)) for p,q in zip(points,revised))
    if biggest>MAX_CONTACT_SKIN_DISPLACEMENT_METERS+1e-8:
        raise ValueError('Calf relief escaped mobile envelope')
    for side in ('l','r'):
        if sum(region_hits[side].values())<3:
            raise ValueError('Missing actual calf skin on '+side)
    # Accessor payload rewrite is exactly in-place: no added body buffer,
    # vertices, material or animation channel. Morphs remain unchanged.
    _patch_view(glb,{
        attrs['POSITION']:revised,
        attrs['NORMAL']:smoothed,
    })
    doc['accessors'][attrs['POSITION']]['min']=[
        min(p[k] for p in revised) for k in range(3)]
    doc['accessors'][attrs['POSITION']]['max']=[
        max(p[k] for p in revised) for k in range(3)]
    for name,original in preserved.items():
        if doc[name]!=original:
            raise ValueError('Calf sculpt changed original QA mesh graph')
    modified=sum(edit_mask)
    metadata.update({
        'lowerLegContourVersion':940,
        'sourceCuticleFoldSha256':hashlib.sha256(raw).hexdigest(),
        'calfGastrocnemiusMedialLateralApproximate':True,
        'calfSoleusContourApproximate':True,
        'calfBodyPositionVerticesEdited':modified,
        'calfReliefNoTriangleFlip':True,
        'professionalAnatomyComplete':False,
        'biomechanicsCertified':False,
        'continuousCollisionCertified':False,
        'physicalDeviceBenchmarked':False,
        'approved':False,'enabled':False,
    })
    output=glb.bytes()
    if len(output)>MAX_MOBILE_BYTES:
        raise ValueError('Mobile GLB exceeded 1400KiB budget')
    parsed=GLB(output,expected_sha=None)
    if parsed.doc['animations']!=preserved['animations'] or (
        parsed.doc['skins']!=preserved['skins']):
        raise ValueError('Export lost original 55-joint animation')
    retained=parsed.doc['meshes'][0]['primitives'][0]['attributes']
    actual=parsed.accessor(retained['POSITION'])
    if max(norm(sub(a,b)) for a,b in zip(points,actual)) > (
            MAX_CONTACT_SKIN_DISPLACEMENT_METERS+.00001):
        raise ValueError('Roundtrip glTF calf geometry changed unexpectedly')
    return output,{
        'exerciseId':exercise,
        'inputSha256':hashlib.sha256(raw).hexdigest(),
        'outputSha256':hashlib.sha256(output).hexdigest(),
        'bodyVertexCount':len(points),
        'editedSkinnedBodyVertices':modified,
        'jointCount':55,'morphTargets':8,
        'maxBodyDisplacementMeters':round(biggest,8),
        'maxBodyNormalChangeDegrees':round(largest_angle,4),
        'topologyAndEquipmentPreserved':True,
        'normalScaleToAvoidFoldovers':scale,
        'regionCandidateSamples':region_hits,
        'trianglesFlipped':0,'realMobileSkinSurface':True,
        'expertAnatomicalReviewComplete':False,
        'motionBiomechanicsCertified':False,
        'physicalDeviceValidated':False,
        'bytes':len(output),
        'approved':False,'enabled':False,
    }


def build(source_dir,output_dir):
    source_dir,output_dir=Path(source_dir),Path(output_dir)
    output_dir.mkdir(parents=True,exist_ok=True)
    items=[]
    for exercise in EXERCISES:
        raw=(source_dir/(exercise+'_v939_cuticle_fold_mobile_qa.glb')
             ).read_bytes()
        data,row=sculpt(raw,exercise)
        (output_dir/(exercise+'_v940_lower_leg_anatomy_mobile_qa.glb')
         ).write_bytes(data)
        items.append(row)
    report={
        'schema':'stk_v940_bilateral_gastrocnemius_soleus_sculpt_qa',
        'catalogCount':229,'pilotCount':3,
        'calfContourFieldsPerSide':3,
        'unchangedAnimationJoints':55,
        'unchangedCorrectiveMorphTargets':8,
        'anatomyProfessionallyApproved':False,
        'physicalDeviceBenchmarked':False,
        'continuousCollisionCertified':False,
        'productionReady':False,'approved':False,'enabled':False,
        'pilots':items,
    }
    (output_dir/'lower_leg_contours_v940_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--input',type=Path,required=True)
    cli.add_argument('--output',type=Path,required=True)
    args=cli.parse_args()
    result=build(args.input,args.output)
    print(json.dumps({'schema':result['schema'],
                      'pilots':result['pilotCount'],
                      'approved':False},indent=2))
