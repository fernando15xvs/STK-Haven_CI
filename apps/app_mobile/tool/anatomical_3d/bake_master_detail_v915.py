#!/usr/bin/env python3
"""v9.15 experimental high-poly muscle surface and mobile normal-detail transfer.

Refines the four v9.14 55-bone high-resolution CC0 review meshes with bounded,
anatomically *suggestive* but NOT clinically grounded lobe/tendon relief.
Bakes ONLY per-vertex shading normals into the original 4,727-vertex v8 mobile
LOD. No change to mobile geometry, skin, 8 corrective morphs or animation.
Always disabled and never packaged as an exercise catalog asset.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from retarget_cc0_glb import GLB, SOURCE_SHA
from build_master_surface_v6 import replace_accessor
from build_master_anatomy_v8 import REGION_ORDER, EXERCISE_IDS
from build_master_surface_v2 import cross, sub

HIGH_VERTICES = 19004
LOW_VERTICES = 4727
HIGH_TRIANGLES = 39372
MAX_HIGH_BYTES = 6 * 1024 * 1024
MAX_MASTER_LOD_BYTES = 850 * 1024
MAX_EXERCISE_LOD_BYTES = 1400 * 1024
MAX_DETAIL_DISPLACEMENT = .0024  # meters; never anatomical ground truth
MAX_NORMAL_CHANGE_DEG = 12.0
MAX_SHADING_BLEND = .42
MIN_SURFACE_EDITS = 350

# Region-specific envelope, capped again by local taper and fold tests.
DETAIL_METERS = {
    'pectoralis_major': .00175,
    'anterior_deltoid': .00135,
    'posterior_deltoid': .00135,
    'triceps_brachii': .00105,
    'latissimus_dorsi': .00140,
    'rhomboids': .00065,
    'middle_trapezius': .00075,
    'quadriceps_femoris': .00175,
    'gluteus_maximus': .00145,
    'hamstrings': .00125,
    'adductor_magnus': .00090,
}

def dot(a,b):
    return sum(x*y for x,y in zip(a,b))

def length(a):
    return math.sqrt(dot(a,a))

def unit(a):
    size=length(a)
    if not math.isfinite(size) or size<1e-10:
        raise ValueError('Nonfinite or degenerate normal')
    return tuple(x/size for x in a)

def smooth(t):
    t=max(0.,min(1.,t))
    return t*t*(3.-2.*t)

def _assert_source(glb, high, exercise=None):
    doc=glb.doc
    meta=doc.get('extras',{})
    if (meta.get('sourceSha256')!=SOURCE_SHA or
        meta.get('approved') is not False or
        meta.get('enabled') is not False or
        meta.get('anatomyArtVersion')!=913 or
        meta.get('masterSculptDetailVersion')!=8 or
        len(doc.get('skins',[]))!=1 or
        len(doc['skins'][0]['joints'])!=55 or
        len(doc.get('animations',[]))!=(7 if exercise is None else 1) or
        len(doc.get('meshes',[]))!=(1 if exercise is None else
             (3 if exercise=='ex_bench_press' else 2)) or
        len(doc['meshes'][0]['primitives'])!=12 or
        (meta.get('anatomyAuthoringVersion')==914)!=high):
        raise ValueError('Untrusted high/low anatomy source')
    if exercise is not None and (exercise not in EXERCISE_IDS or
        meta.get('exerciseId')!=exercise or
        meta.get('masterExercisePilotVersion')!=910):
        raise ValueError('Unexpected exercise provenance')
    prims=doc['meshes'][0]['primitives']
    if {p['extras']['stkMuscleRegion'] for p in prims} != set(REGION_ORDER)|{'body'}:
        raise ValueError('Missing eleven-region muscle atlas')
    attrs=prims[0]['attributes']
    if any(p['attributes']!=attrs or
           p['targets']!=prims[0]['targets'] for p in prims):
        raise ValueError('Corrupt shared anatomical skin/morph streams')
    points=glb.accessor(attrs['POSITION'])
    normals=glb.accessor(attrs['NORMAL'])
    expected=HIGH_VERTICES if high else LOW_VERTICES
    if len(points)!=expected or len(normals)!=expected:
        raise ValueError('Wrong high/low poly vertex count')
    if len(prims[0]['targets'])!=8:
        raise ValueError('Missing eight corrective shapes')
    return prims,attrs,points,normals

def _atlas(glb,prims,n):
    vote={name:[0]*n for name in DETAIL_METERS}
    touched=[0]*n
    triangles=[]
    for part in prims:
        region=part['extras']['stkMuscleRegion']
        ids=[int(x[0]) for x in glb.accessor(part['indices'])]
        if len(ids)%3:
            raise ValueError('Malformed high-poly face list')
        for i in ids:
            if i<0 or i>=n:
                raise ValueError('Out-of-range region face vertex')
            touched[i]+=1
            if region in vote:
                vote[region][i]+=1
        for k in range(0,len(ids),3):
            triangles.append(tuple(ids[k:k+3]))
    if len(triangles)!=HIGH_TRIANGLES:
        raise ValueError('High-poly authoring face count changed')
    mask={name:[hit/max(1,total) for hit,total in zip(vote[name],touched)]
          for name in vote}
    return mask,triangles

def _profiles(points,masks):
    profiles={}
    for region,mask in masks.items():
        for side in (-1,1):
            population=[(points[i],mask[i]) for i in range(len(points))
                        if mask[i]>.03 and points[i][0]*side>.012]
            total=sum(weight for _,weight in population)
            if total<10:
                raise ValueError('Missing bilateral region '+region)
            center=tuple(sum(point[k]*weight for point,weight in population)/
                         total for k in range(3))
            radius=tuple(max(.027,math.sqrt(
                sum((point[k]-center[k])**2*weight
                    for point,weight in population)/total)*1.85)
                for k in range(3))
            profiles[(region,side)]=(center,radius)
    return profiles

def _muscle_shape(region,local):
    """Artist-oriented contours, not segmented anatomical insertions."""
    x,y,z=local
    if region=='pectoralis_major':
        return .86+.14*math.exp(-2.5*(y+.20)**2)
    if region in ('anterior_deltoid','posterior_deltoid'):
        return .80+.20*math.exp(-3.0*(x-.30)**2)
    if region=='triceps_brachii':
        return .80+.20*math.cos(1.7*y)**2
    if region=='latissimus_dorsi':
        return .82+.18*smooth((y+1.3)/2.6)
    if region in ('rhomboids','middle_trapezius'):
        return .90+.10*math.exp(-2.0*x*x)
    if region=='quadriceps_femoris':
        return .78+.22*math.cos(2.3*x+.35)**2
    if region=='gluteus_maximus':
        return .86+.14*math.exp(-2.0*y*y)
    if region=='hamstrings':
        return .83+.17*math.cos(1.8*x-.30)**2
    return .90+.10*math.exp(-2.*y*y)

def _sculpt(points,normals,masks):
    profiles=_profiles(points,masks)
    offset=[]
    active_regions={name:0 for name in DETAIL_METERS}
    for i,(point,normal) in enumerate(zip(points,normals)):
        side=1 if point[0]>0 else -1
        if abs(point[0])<.016:
            offset.append(0.)
            continue
        value=0.
        for region,limit in DETAIL_METERS.items():
            membership=smooth((masks[region][i]-.06)/.65)
            if membership<.00001:
                continue
            center,radius=profiles[(region,side)]
            local=tuple((point[k]-center[k])/radius[k] for k in range(3))
            r2=sum(k*k for k in local)
            # Taper tendon-like edges toward each region boundary; this is
            # an artistic volume transition, never physical tendon geometry.
            belly=math.exp(-.90*r2)*_muscle_shape(region,local)
            amount=limit*membership*belly
            value+=amount
            if amount>.00006:active_regions[region]+=1
        value=min(MAX_DETAIL_DISPLACEMENT,value)
        value*=smooth((abs(point[0])-.016)/.034)
        offset.append(value)
    if any(v==0 for v in active_regions.values()):
        raise ValueError('One or more anatomical atlas regions not sculpted')
    if sum(x>.00002 for x in offset)<MIN_SURFACE_EDITS:
        raise ValueError('No meaningful authoring surface changes')
    return offset,active_regions

def _oriented(original,trial,faces):
    violations=0
    for a,b,c in faces:
        before=cross(sub(original[b],original[a]),sub(original[c],original[a]))
        if length(before)<=1e-11:
            continue
        after=cross(sub(trial[b],trial[a]),sub(trial[c],trial[a]))
        if dot(before,after)<=0:
            violations+=1
    return violations

def _new_normals(points,prior,faces):
    accumulation=[[0.,0.,0.] for _ in points]
    for a,b,c in faces:
        vector=cross(sub(points[b],points[a]),sub(points[c],points[a]))
        if length(vector)<=1e-13:
            continue
        for i in (a,b,c):
            for k in range(3):
                accumulation[i][k]+=vector[k]
    revised=[]
    for before,vector in zip(prior,accumulation):
        old=unit(before)
        if length(vector)<1e-12:
            revised.append(old)
            continue
        guess=unit(vector)
        if dot(guess,old)<0:guess=tuple(-x for x in guess)
        revised.append(unit(tuple(.25*old[k]+.75*guess[k]
                                  for k in range(3))))
    return revised

def _safe_sculpt(points,normals,faces,masks):
    displacements,region_hits=_sculpt(points,normals,masks)
    best=None
    for factor in (1.,.65,.4,.2,.1):
        trial=[tuple(point[k]+normal[k]*displacements[i]*factor
                     for k in range(3)) for i,(point,normal)
                     in enumerate(zip(points,normals))]
        flipped=_oriented(points,trial,faces)
        if not flipped:
            best=(trial,factor)
            break
    if best is None:
        raise ValueError('Cannot sculpt without inverted faces')
    out,factor=best
    actual=max(math.dist(a,b) for a,b in zip(points,out))
    if actual>MAX_DETAIL_DISPLACEMENT+1e-6:
        raise ValueError('Authoring relief escaped bounded envelope')
    refined_normals=_new_normals(out,normals,faces)
    return out,refined_normals,{'maxDisplacementMeters':round(actual,7),
      'scaleToAvoidFoldover':factor,'flippedTriangles':0,
      'affectedHighResVertices':sum(
          math.dist(a,b)>.00002 for a,b in zip(points,out)),
      'affectedRegions':region_hits}

def _bake_normals(source_low,high_old,high_refined,low_prior,high_prior):
    if len(source_low)!=LOW_VERTICES or len(high_old)!=HIGH_VERTICES:
        raise ValueError('Wrong LOD correspondence')
    baked=[];max_angle=0.;edits=0
    rad_limit=math.radians(MAX_NORMAL_CHANGE_DEG)
    for i,point in enumerate(source_low):
        if math.dist(point,high_old[i])>1e-5:
            raise ValueError('Mobile mesh not embedded in v9.14 authoring mesh')
        before=unit(low_prior[i])
        target=unit(high_refined[i])
        if dot(before,target)<0:target=tuple(-v for v in target)
        cosine=max(-1.,min(1.,dot(before,target)))
        angle=math.acos(cosine)
        alpha=MAX_SHADING_BLEND*min(1.,rad_limit/max(1e-9,angle))
        update=unit(tuple((1-alpha)*before[k]+alpha*target[k]
                          for k in range(3)))
        new_angle=math.acos(max(-1.,min(1.,dot(before,update))))
        max_angle=max(max_angle,new_angle)
        if new_angle>.0005:edits+=1
        baked.append(update)
    if max_angle>rad_limit+.0002 or edits<75:
        raise ValueError('Unsafe or imperceptible mobile normal bake')
    return baked,{'changedMobileNormals':edits,
                  'maximumNormalDeviationDegrees':round(
                      math.degrees(max_angle),5),
                  'mobilePositionsUnchanged':True,
                  'mobileTrianglesUnchanged':True}

def _write(glb,attr,positions=None,normals=None,high=False,source_sha=''):
    if positions is not None:
        replace_accessor(glb,attr['POSITION'],positions)
        glb.doc['accessors'][attr['POSITION']]['min']=[
            min(v[k] for v in positions) for k in range(3)]
        glb.doc['accessors'][attr['POSITION']]['max']=[
            max(v[k] for v in positions) for k in range(3)]
    if normals is not None:
        replace_accessor(glb,attr['NORMAL'],normals)
    glb.doc['extras']=dict(glb.doc.get('extras',{}),
        anatomyShadingVersion=915,detailTransferHighResSha256=source_sha,
        highResDetailAuthoring=high,mobileNormalDetailBaked=not high,
        approved=False,enabled=False,
        detailArtReviewed=False,biomechanicsApproved=False)
    raw=glb.bytes()
    return raw

def build(master_high,master_low,exercise_high,exercise_low,out_dir):
    high_files={None:Path(master_high),
       **{ex:Path(exercise_high)/(ex+'_master55_v914_high_res_qa.glb')
          for ex in EXERCISE_IDS}}
    low_files={None:Path(master_low),
       **{ex:Path(exercise_low)/(ex+'_master55_v8_sculpt_qa.glb')
          for ex in EXERCISE_IDS}}
    root=Path(out_dir);root.mkdir(parents=True,exist_ok=True)
    template=GLB(high_files[None].read_bytes(),expected_sha=None)
    prims,attrs,positions,normals=_assert_source(template,True)
    masks,faces=_atlas(template,prims,len(positions))
    surface,updated_normals,geometry_report=_safe_sculpt(
        positions,normals,faces,masks)
    reports=[]
    for ex in (None,*EXERCISE_IDS):
        high_bytes=high_files[ex].read_bytes()
        low_bytes=low_files[ex].read_bytes()
        hi=GLB(high_bytes,expected_sha=None)
        lo=GLB(low_bytes,expected_sha=None)
        _,hattr,hpos,hnormal=_assert_source(hi,True,ex)
        _,lattr,lpos,lnormal=_assert_source(lo,False,ex)
        if len(hpos)!=len(positions) or any(
            math.dist(a,b)>2e-6 for a,b in zip(hpos,positions)):
            raise ValueError('Exercise high-res neutral surface differs from master')
        if any(math.dist(a,b)>2e-6 for a,b in zip(lpos,positions)):
            raise ValueError('Exercise mobile LOD not aligned with artist master')
        if len(hi.doc['meshes'][0]['primitives'])!=12:
            raise ValueError('Missing artist mesh')
        baked,bake_report=_bake_normals(lpos,positions,
                                        updated_normals,lnormal,hnormal)
        result_hi=_write(hi,hattr,positions=surface,
                         normals=updated_normals,high=True,
                         source_sha=hashlib.sha256(high_bytes).hexdigest())
        result_lo=_write(lo,lattr,normals=baked,high=False,
                         source_sha=hashlib.sha256(result_hi).hexdigest())
        if len(result_hi)>MAX_HIGH_BYTES or len(result_lo)>(
                MAX_MASTER_LOD_BYTES if ex is None else
                MAX_EXERCISE_LOD_BYTES):
            raise ValueError('High/poly LOD byte budget violated')
        basename=('stk_master' if ex is None else ex)
        (root/(basename+'_v915_high_detail_authoring.glb')).write_bytes(result_hi)
        (root/(basename+'_v915_mobile_normal_bake_qa.glb')).write_bytes(result_lo)
        reports.append({'exerciseId':ex,'master':ex is None,
            'authoringBytes':len(result_hi),
            'mobileBytes':len(result_lo),
            'sourceHiSha256':hashlib.sha256(high_bytes).hexdigest(),
            'hiSha256':hashlib.sha256(result_hi).hexdigest(),
            'mobileSha256':hashlib.sha256(result_lo).hexdigest(),
            'bake':bake_report,'approved':False,'enabled':False})
    report={'schema':'stk_anatomy_detail_bake_v915_QA_only',
        'catalogCount':229,'rigJoints':55,'morphs':8,'muscleRegions':11,
        'highVertices':HIGH_VERTICES,'mobileVertices':LOW_VERTICES,
        'highTriangles':HIGH_TRIANGLES,'anatomyClinicallyValidated':False,
        'deviceGpuValidated':False,'productionReady':False,
        'approved':False,'enabled':False,
        'geometry':geometry_report,'assets':reports}
    (root/'normal_bake_v915_report.json').write_text(
        json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--high-master',type=Path,required=True)
    parser.add_argument('--low-master',type=Path,required=True)
    parser.add_argument('--high-pilots',type=Path,required=True)
    parser.add_argument('--low-pilots',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    a=parser.parse_args()
    print(json.dumps(build(a.high_master,a.low_master,a.high_pilots,
                            a.low_pilots,a.output),indent=2))
